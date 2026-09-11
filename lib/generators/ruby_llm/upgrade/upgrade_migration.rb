# frozen_string_literal: true

module RubyLLM
  module Generators
    class UpgradeMigration # :nodoc: all
      TABLE = :ruby_llm_v2_upgrades
      VERSION_COLUMN = :ruby_llm_version

      def self.for(connection: ::ActiveRecord::Base.connection)
        require_relative 'online_copy_migration'
        OnlineCopyMigration.new(connection:)
      end

      def initialize(connection: ::ActiveRecord::Base.connection)
        @connection = connection
      end

      def prepare(settings)
        create_state_table unless @connection.table_exists?(TABLE)
        prepare_state(settings)
        yield if block_given?
      end

      def prepare_state(settings)
        existing = states.first
        if existing
          raise 'This database has a different RubyLLM copy upgrade' unless existing.settings == settings.stringify_keys
          unless existing.status == 'preparing' || (existing.active_version == 1 && existing.needs_reconcile)
            raise 'The copy upgrade is already active'
          end

          existing.update!(status: 'preparing')
        else
          states.create!(settings: settings.stringify_keys)
        end
      end
      private :prepare_state

      def online? = false

      def copy_table(source, target)
        return if @connection.table_exists?(target)

        source_records = records(source)
        create_copy_table(source, target)
        columns = source_records.column_names & records(target).column_names
        names = columns.map { |column| @connection.quote_column_name(column) }.join(', ')
        key = @connection.quote_column_name(source_records.primary_key)
        @connection.execute(<<~SQL)
          INSERT INTO #{@connection.quote_table_name(target)} (#{names})
          SELECT #{names} FROM #{@connection.quote_table_name(source)}
          WHERE #{key} NOT IN (SELECT #{key} FROM #{@connection.quote_table_name(target)})
        SQL
        @connection.reset_pk_sequence!(target) if @connection.respond_to?(:reset_pk_sequence!)
      end

      def copy_model_references
        records(configuration.fetch('chat_table')).find_each do |chat|
          model = resolve_model(chat[configuration.fetch('model_foreign_key')])
          chat.update!(ruby_llm_model_id: model&.id)
        end
      end

      def backfill(force: true)
        state = states.first!
        state.with_lock do
          unless %w[preparing reconciling].include?(state.status) ||
                 (state.active_version == 1 && state.needs_reconcile)
            raise 'Expected an unfinished copy upgrade'
          end
          return if !force && !state.needs_reconcile

          state.update!(status: 'preparing', needs_reconcile: true)
        end
        reconcile
        state.update!(needs_reconcile: false)
      end

      def activate
        state = states.first!
        return if state.active_version == 2 && state.status == 'active'

        unless %w[preparing reconciling].include?(state.status) || (state.active_version == 1 && state.needs_reconcile)
          raise 'Expected an unfinished copy upgrade'
        end

        raise 'Run the copy backfill before activating 2.0' if state.needs_reconcile

        state.update!(active_version: 2, status: 'active', needs_reconcile: false)
      end

      def verify_settings(settings)
        return if configuration == settings.stringify_keys

        raise 'Use the same model mappings for every copy-upgrade phase'
      end

      def rollback
        state = states.first!
        if state.active_version == 1 && %w[preparing reconciling].include?(state.status)
          state.with_lock do
            state.update!(status: 'active', needs_reconcile: state.needs_reconcile || state.status == 'preparing')
          end
          return
        end
        transition(2, 1) { verify_completed_work }
      end

      def resume
        state = states.first!
        state.with_lock do
          unless state.active_version == 1 && %w[active reconciling].include?(state.status)
            raise 'Resume requires a copy upgrade running on 1.16'
          end
          raise 'Finish the initial copy migrations before resuming 2.0' if state.needs_reconcile

          state.update!(status: 'reconciling')
        end
        reconcile
        state.update!(active_version: 2, status: 'active')
      end

      def finalize
        state = states.first!
        state.with_lock do
          require_active_version(state, 2)
          verify_completed_work
          state.update!(status: 'finalized')
        end
      end

      def verify_cleanup
        state = states.first!
        return if state.active_version == 2 && state.status == 'finalized'

        raise 'Run ruby_llm:upgrade:finalize on 2.0 before copy-mode cleanup'
      end

      def cleanup
        verify_cleanup
        settings = configuration
        legacy_tables = settings.values_at('model_table', 'tool_call_table')
        remove_legacy_foreign_keys(legacy_tables)
        chats = settings.fetch('chat_table')
        column = settings.fetch('model_foreign_key')
        @connection.remove_column(chats, column) if @connection.column_exists?(chats, column)
        @connection.remove_column(chats, VERSION_COLUMN) if @connection.column_exists?(chats, VERSION_COLUMN)
        legacy_tables.reverse_each { |table| @connection.drop_table(table) if @connection.table_exists?(table) }
      end

      private

      def create_state_table
        if %i[ruby_llm_models ruby_llm_tool_calls].any? { |table| @connection.table_exists?(table) }
          raise 'Copy mode requires new RubyLLM supporting tables; do not reuse an earlier upgrade'
        end

        @connection.create_table(TABLE) do |table|
          table.integer :active_version, null: false, default: 1
          table.string :status, null: false, default: 'preparing'
          table.boolean :needs_reconcile, null: false, default: false
          table.bigint :epoch, null: false, default: 0
          table.json :settings, null: false
        end
      end

      def create_copy_table(source, target)
        primary = @connection.columns(source).find { |column| column.name == records(source).primary_key }
        @connection.create_table(target, primary_key: primary.name, id: copy_primary_options(primary)) do |table|
          @connection.columns(source).each do |column|
            next if column.name == primary.name

            table.column(column.name, column.type, **copy_column_options(source, column))
          end
        end
      end

      def copy_primary_options(primary)
        type = primary.type == :integer && primary.limit == 8 ? :bigint : primary.type
        unless %i[integer bigint uuid].include?(type)
          raise 'Copy mode requires integer or UUID model/tool-call primary keys'
        end

        options = { type: type }
        options[:default] = -> { primary.default_function } if type == :uuid && primary.default_function
        options
      end

      def copy_column_options(source, column)
        options = { null: column.null, limit: column.limit, precision: column.precision, scale: column.scale }.compact
        options[:default] = if column.default_function
                              -> { column.default_function }
                            else
                              records(source).type_for_attribute(column.name).deserialize(column.default)
                            end
        options
      end

      def remove_legacy_foreign_keys(legacy_tables)
        (@connection.tables - legacy_tables).each do |table|
          @connection.foreign_keys(table).each do |key|
            next unless legacy_tables.include?(key.to_table)

            allowed = table == configuration['chat_table'] && key.column == configuration['model_foreign_key']
            raise "Move the application foreign key #{table}.#{key.column} before cleanup" unless allowed

            @connection.remove_foreign_key(table, column: key.column)
          end
        end
      end

      def states
        records(TABLE)
      end

      def configuration
        @configuration ||= states.first!.settings
      end

      def records(table)
        @records ||= {}
        @records[table.to_s] ||= Class.new(::ActiveRecord::Base) do
          self.table_name = table.to_s
          self.inheritance_column = :_type_disabled
        end.tap(&:reset_column_information)
      end

      def transition(from, to)
        state = states.first!
        state.with_lock do
          require_active_version(state, from)
          yield
          state.update!(active_version: to)
        end
      end

      def require_active_version(state, version)
        return if state.active_version == version && state.status == 'active'

        raise "The copy upgrade must be active on version #{version}"
      end

      def verify_completed_work
        if @connection.table_exists?(:ruby_llm_batches) && records(:ruby_llm_batches).where(completed: false).exists?
          raise 'Finish or cancel pending RubyLLM batches before switching versions'
        end

        calls = records(:ruby_llm_tool_calls).where(message_type: configuration.fetch('message_class'), result_id: nil)
        return unless calls.exists?

        raise 'Finish pending tool calls and approvals before switching versions'
      end

      def reconcile
        settings = configuration
        chats = records(settings.fetch('chat_table'))
        messages = records(settings.fetch('message_table'))
        protected_chats = chats.where(VERSION_COLUMN => 2).select(chats.primary_key)
        protected_messages = messages.where(settings.fetch('chat_foreign_key') => protected_chats)
                                     .select(messages.primary_key)
        records(:ruby_llm_tool_calls).where(message_type: settings.fetch('message_class'))
                                     .where.not(message_id: protected_messages).delete_all
        records(:ruby_llm_usages).where(chat_type: settings.fetch('chat_class'))
                                 .where.not(chat_id: protected_chats).delete_all
        chats.where(VERSION_COLUMN => 1).find_each do |chat|
          chats.transaction { reconcile_chat(chat) }
        end
      end

      def reconcile_chat(chat)
        settings = configuration
        model = resolve_model(chat[settings.fetch('model_foreign_key')])
        raise "Chat #{chat.id} has no identifiable legacy model" unless model

        chat.update!(ruby_llm_model_id: model.id)
        messages = records(settings.fetch('message_table')).where(settings.fetch('chat_foreign_key') => chat.id)
        messages.find_each do |message|
          source = message.attributes
          raw = source['content_raw']
          message.update!(raw_content: raw, content: raw.present? ? JSON.generate(raw) : source['content'])
          reconcile_usage(chat, message, source, model)
        end
        reconcile_tools(messages)
      end

      def resolve_model(id)
        return unless id

        legacy = records(configuration.fetch('model_table')).find(id)
        target = records(:ruby_llm_models)
        target.find_by(provider: legacy.provider, model_id: legacy.model_id) ||
          target.create!(legacy.attributes.slice(*target.column_names).except(target.primary_key))
      end

      def reconcile_tools(messages)
        settings = configuration
        source = records(settings.fetch('tool_call_table'))
        target = records(:ruby_llm_tool_calls)
        ids = messages.select(messages.klass.primary_key)
        source.where(settings.fetch('message_foreign_key') => ids).find_each do |call|
          result = messages.find_by(settings.fetch('tool_call_foreign_key') => call.id)
          raise "Finish legacy tool call #{call.id} before resuming 2.0" unless result

          attributes = call.attributes.slice(*target.column_names).except(target.primary_key)
          attributes.merge!(
            message_type: settings.fetch('message_class'), message_id: call[settings.fetch('message_foreign_key')],
            result_type: settings.fetch('message_class'), result_id: result.id,
            tool_call_id: verified_tool_id(target, call)
          )
          target.create!(attributes)
        end
      end

      def verified_tool_id(target, call)
        if target.exists?(tool_call_id: call.tool_call_id)
          raise "Tool call #{call.id} repeats provider ID #{call.tool_call_id.inspect}; " \
                'reconcile its history before retrying'
        end

        call.tool_call_id
      end

      def reconcile_usage(chat, message, source, chat_model)
        tokens = legacy_tokens(source)
        costs = legacy_costs(source)
        return unless source['role'] == 'assistant' || (tokens.values + costs.values).any?

        model = resolve_model(source[configuration.fetch('model_foreign_key')]) || chat_model
        raise "Message #{message.id} has no identifiable model" unless model

        attributes = tokens.merge(costs).merge(
          chat_type: configuration.fetch('chat_class'), chat_id: chat.id,
          message_type: configuration.fetch('message_class'), message_id: message.id,
          operation: 'chat', provider: model.provider, model: model.model_id, status: 'succeeded',
          created_at: source['created_at'], updated_at: source['updated_at']
        )
        records(:ruby_llm_usages).create!(attributes)
      end

      def legacy_tokens(source)
        {
          input_tokens: source['input_tokens'], output_tokens: source['output_tokens'],
          cache_read_tokens: source['cache_read_tokens'] || source['cached_tokens'],
          cache_write_tokens: source['cache_write_tokens'] || source['cache_creation_tokens'],
          thinking_tokens: source['thinking_tokens']
        }
      end

      def legacy_costs(source)
        details = source['cost_details'] || {}
        details = JSON.parse(details) if details.is_a?(String)
        costs = %w[input output cache_read cache_write thinking].to_h { |name| ["#{name}_cost", details[name]] }
        costs['total_cost'] = source['total_cost'] || details['total']
        costs
      end
    end
  end
end
