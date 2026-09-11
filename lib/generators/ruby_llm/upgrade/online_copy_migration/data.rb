# frozen_string_literal: true

require 'json'
require_relative '../legacy_content_sql'
require_relative 'verification'

module RubyLLM
  module Generators
    class OnlineCopyMigration < UpgradeMigration
      class Data < UpgradeMigration # :nodoc: all
        BATCH_SIZE = 10_000
        PROGRESS = :ruby_llm_v2_backfills
        TASKS = %w[message_content tool_results usages].freeze

        def initialize(connection:, settings:)
          super(connection:)
          @configuration = settings
        end

        def prepare
          messages = configuration.fetch('message_table')
          unless @connection.column_exists?(messages, :ruby_llm_content)
            @connection.add_column(messages, :ruby_llm_content, :text)
          end
          %i[ruby_llm_tool_calls ruby_llm_usages].each do |table|
            @connection.add_column(table, :legacy_key, :string) unless @connection.column_exists?(table, :legacy_key)
            unless @connection.index_exists?(table, :legacy_key, unique: true)
              @connection.add_index(table, :legacy_key, unique: true)
            end
          end
          return if @connection.column_exists?(:ruby_llm_tool_calls, :legacy_chat_id)

          @connection.add_column(:ruby_llm_tool_calls, :legacy_chat_id, :string)
          @connection.add_index(:ruby_llm_tool_calls, :legacy_chat_id)
        end

        def backfill
          prepare_progress
          sync_models
          sync_chat_models
          TASKS.each do |task|
            progress = records(PROGRESS).find_or_create_by!(task:)
            next if progress.completed

            unless progress.upper_id
              upper = messages.order(messages.primary_key => :desc).pick(messages.primary_key)
              unless upper
                progress.update!(completed: true)
                next
              end
              progress.update!(upper_id: upper&.to_s)
            end
            relation = legacy_messages
            relation = relation.where("#{q(messages.primary_key)} <= ?", progress.upper_id) if progress.upper_id
            relation = relation.where("#{q(messages.primary_key)} > ?", progress.last_id) if progress.last_id
            each_batch(relation) do |batch|
              messages.transaction do
                copy_batch(task, batch)
                progress.update!(last_id: batch.last.id)
              end
            end
            progress.update!(completed: true)
          end
        end

        def catch_up(passes: nil)
          sync_models
          pass = 0
          loop do
            upper = changes.maximum(:id)
            break unless upper

            changes.where(id: ..upper).in_batches(of: 100) do |events|
              captured = events.to_a
              chat_ids = affected_chats(captured)
              sync_chat_models(chat_ids)
              reconcile_chats(chat_ids)
              acknowledge(captured)
            end
            pass += 1
            break if passes && pass >= passes
          end
        end

        def completed?
          @connection.table_exists?(PROGRESS) &&
            (TASKS - records(PROGRESS).where(completed: true).pluck(:task)).empty?
        end

        def finished?
          @connection.table_exists?(PROGRESS) && records(PROGRESS).where(task: 'finished', completed: true).exists?
        end

        def sync_models
          refresh = !finished?
          records(configuration.fetch('model_table')).find_each(batch_size: BATCH_SIZE) do |model|
            target = resolve_model(model.id)
            next unless refresh

            attributes = model.attributes.slice(*target.class.column_names).except(target.class.primary_key)
            target.assign_attributes(attributes)
            target.save! if target.changed?
          end
        end

        def sync_chat_models(ids = nil)
          relation = chats.where(VERSION_COLUMN => 1)
          relation = relation.where(chats.primary_key => ids) if ids
          models = records(configuration.fetch('model_table')).all.to_h do |model|
            [model.id, resolve_model(model.id).id]
          end
          models.each do |legacy_id, target_id|
            relation.where(configuration.fetch('model_foreign_key') => legacy_id)
                    .where('ruby_llm_model_id IS NULL OR ruby_llm_model_id != ?', target_id)
                    .update_all(ruby_llm_model_id: target_id)
          end
        end

        def verify
          raise 'The online copy journal is not empty; keep AI activity paused' if changes.exists?
          raise 'RubyLLM 2.0 backfills are incomplete' unless completed?

          tables = [configuration.fetch('chat_table'), configuration.fetch('message_table'),
                    'ruby_llm_models', 'ruby_llm_tool_calls', 'ruby_llm_usages']
          if @connection.adapter_name == 'PostgreSQL'
            @connection.execute("ANALYZE #{tables.map { |table| qt(table) }.join(', ')}")
          end
          Verification.new(connection: @connection, settings: configuration).verify
        end

        def cleanup
          table = configuration.fetch('message_table')
          if @connection.column_exists?(table, :ruby_llm_content)
            @connection.remove_column(table, :content) if @connection.column_exists?(table, :content)
            @connection.rename_column(table, :ruby_llm_content, :content)
          end
          columns = %i[legacy_key legacy_chat_id]
          %i[ruby_llm_tool_calls ruby_llm_usages].each do |target|
            columns.each do |column|
              next unless @connection.column_exists?(target, column)

              @connection.remove_index(target, column) if @connection.index_exists?(target, column)
              @connection.remove_column(target, column)
            end
          end
        end

        private

        def acknowledge(events)
          matches = events.map { |event| "(id = #{Integer(event.id)} AND revision = #{Integer(event.revision)})" }
          changes.where(matches.join(' OR ')).delete_all if matches.any?
        end

        def prepare_progress
          unless @connection.table_exists?(PROGRESS)
            @connection.create_table(PROGRESS) do |table|
              table.string :task, null: false, index: { unique: true }
              table.string :last_id
              table.boolean :completed, null: false, default: false
            end
          end
          @connection.add_column(PROGRESS, :upper_id, :string) unless @connection.column_exists?(PROGRESS, :upper_id)
          records(PROGRESS).reset_column_information
        end

        def copy_batch(task, batch)
          case task
          when 'message_content' then copy_content(batch.map(&:id))
          when 'tool_results' then copy_tools(batch)
          when 'usages' then upsert(:ruby_llm_usages, usage_attributes(batch))
          end
        end

        def copy_content(ids)
          raw = @connection.column_exists?(messages.table_name, :content_raw) ? q(:content_raw) : 'NULL'
          text = LegacyContentSQL.new(@connection).render(content: q(:content), raw:)
          structured = @connection.adapter_name == 'PostgreSQL' ? "#{raw}::jsonb" : raw
          messages.where(messages.primary_key => ids).update_all(
            "#{q(:ruby_llm_content)} = #{text}, #{q(:raw_content)} = #{structured}"
          )
        end

        def copy_tools(batch)
          ids = batch.map(&:id)
          source = records(configuration.fetch('tool_call_table'))
          key = configuration.fetch('message_foreign_key')
          result_key = configuration.fetch('tool_call_foreign_key')
          calls = source.where(key => ids).to_a
          results = messages.where(result_key => calls.map(&:id)).to_a.group_by { |message| message[result_key] }
          chat_ids = batch.to_h { |message| [message.id, message[configuration.fetch('chat_foreign_key')]] }
          target = records(:ruby_llm_tool_calls)
          attributes = calls.map do |call|
            tool_attributes(call, results.fetch(call.id, []), chat_ids.fetch(call[key]), target)
          end
          verify_tool_ids(target, attributes)
          upsert(:ruby_llm_tool_calls, attributes)
        end

        def tool_attributes(call, results, chat_id, target)
          raise "Multiple messages reference tool call #{call.id}" if results.size > 1

          call.attributes.slice(*target.column_names).except(target.primary_key).symbolize_keys.merge(
            legacy_key: call.id.to_s, legacy_chat_id: chat_id.to_s,
            message_type: configuration.fetch('message_class'),
            message_id: call[configuration.fetch('message_foreign_key')],
            result_type: results.any? ? configuration.fetch('message_class') : nil, result_id: results.first&.id
          )
        end

        def verify_tool_ids(target, attributes)
          provider_ids = attributes.map { |row| row[:tool_call_id] }
          reserved = target.where(tool_call_id: provider_ids).pluck(:tool_call_id, :legacy_key).to_h
          attributes.each do |row|
            next unless reserved.key?(row[:tool_call_id]) && reserved[row[:tool_call_id]] != row[:legacy_key]

            raise "Tool call #{row[:legacy_key]} repeats provider ID #{row[:tool_call_id].inspect}"
          end
        end

        def usage_attributes(batch)
          models = records(configuration.fetch('model_table')).all.index_by(&:id)
          chat_ids = batch.map { |message| message[configuration.fetch('chat_foreign_key')] }
          chat_models = chats.where(chats.primary_key => chat_ids)
                             .pluck(chats.primary_key, configuration.fetch('model_foreign_key')).to_h
          batch.filter_map do |message|
            source = message.attributes
            tokens = legacy_tokens(source)
            costs = legacy_costs(source)
            next unless source['role'] == 'assistant' || (tokens.values + costs.values).any? { |value| !value.nil? }

            chat_id = source.fetch(configuration.fetch('chat_foreign_key'))
            provider, model_id = usage_identity(message, models, chat_models[chat_id])

            tokens.merge(costs).symbolize_keys.merge(
              legacy_key: message.id.to_s, chat_type: configuration.fetch('chat_class'), chat_id:,
              message_type: configuration.fetch('message_class'), message_id: message.id,
              operation: 'chat', provider:, model: model_id, status: 'succeeded',
              created_at: source['created_at'], updated_at: source['updated_at']
            )
          end
        end

        def usage_identity(message, models, chat_model_id)
          key = configuration.fetch('model_foreign_key')
          model = models[message[key]] || models[chat_model_id]
          if string_model_reference?(message, key)
            provider = message.attributes['provider'] || model&.provider
            raise "Message #{message.id} has no identifiable provider" unless provider

            return [provider, message[key]]
          end
          raise "Message #{message.id} has no identifiable legacy model" unless model

          [model.provider, model.model_id]
        end

        def upsert(table, attributes)
          return if attributes.empty?

          options = { record_timestamps: false }
          options[:unique_by] = :legacy_key unless @connection.adapter_name == 'Mysql2'
          records(table).upsert_all(attributes, **options)
        end

        def string_model_reference?(message, key)
          messages.columns_hash[key]&.type == :string && message[key]
        end

        def affected_chats(events)
          ids = events.select { |event| event.kind == 'chat' }.map(&:record_id)
          model_ids = events.select { |event| event.kind == 'model' }.map(&:record_id)
          if model_ids.any?
            sync_models
            key = configuration.fetch('model_foreign_key')
            ids.concat(chats.where(key => model_ids).pluck(chats.primary_key))
            ids.concat(messages.where(key => model_ids).distinct.pluck(configuration.fetch('chat_foreign_key')))
          end
          ids.map(&:to_s).uniq
        end

        def reconcile_chats(ids)
          protected_ids = chats.where(chats.primary_key => ids,
                                      VERSION_COLUMN => 2).pluck(chats.primary_key).map(&:to_s)
          ids -= protected_ids
          return if ids.empty?

          remove_deleted_copies(ids)
          relation = legacy_messages.where(configuration.fetch('chat_foreign_key') => ids)
          upper = relation.order(messages.primary_key => :desc).pick(messages.primary_key)
          relation = relation.where("#{q(messages.primary_key)} <= ?", upper) if upper
          each_batch(relation) do |batch|
            messages.transaction do
              TASKS.each { |task| copy_batch(task, batch) }
              eligible = usage_attributes(batch).map { |row| row[:legacy_key] }
              records(:ruby_llm_usages).where(legacy_key: batch.map { |message| message.id.to_s })
                                       .where.not(legacy_key: eligible).delete_all
            end
          end
          remove_deleted_copies(ids)
        end

        def remove_deleted_copies(ids)
          current = messages.select(messages.primary_key)
          records(:ruby_llm_usages).where(chat_type: configuration.fetch('chat_class'), chat_id: ids)
                                   .where.not(legacy_key: nil).where.not(message_id: current).delete_all
          source = records(configuration.fetch('tool_call_table'))
          records(:ruby_llm_tool_calls).where(legacy_chat_id: ids).where.not(legacy_key: nil).find_in_batches do |batch|
            existing = source.where(source.primary_key => batch.map(&:legacy_key)).pluck(source.primary_key).map(&:to_s)
            removed = batch.reject { |call| existing.include?(call.legacy_key) }.map(&:id)
            records(:ruby_llm_tool_calls).where(id: removed).delete_all if removed.any?
          end
        end

        def each_batch(relation, &)
          relation.find_in_batches(batch_size: BATCH_SIZE, &)
        end

        def legacy_messages
          owned = chats.where(VERSION_COLUMN => 1).select(chats.primary_key)
          messages.where(configuration.fetch('chat_foreign_key') => owned)
        end

        def messages = records(configuration.fetch('message_table'))
        def chats = records(configuration.fetch('chat_table'))
        def changes = records(Journal::TABLE)
        def q(value) = @connection.quote_column_name(value)
        def qt(value) = @connection.quote_table_name(value)
      end
    end
  end
end
