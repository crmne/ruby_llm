# frozen_string_literal: true

module RubyLLM
  module Generators
    class OnlineCopyMigration < UpgradeMigration
      class Journal # :nodoc: all
        TABLE = :ruby_llm_v2_changes
        OPERATIONS = %w[INSERT UPDATE DELETE].freeze
        MESSAGE_COLUMNS = %w[
          role content content_raw input_tokens output_tokens cached_tokens cache_creation_tokens
          cache_read_tokens cache_write_tokens thinking_tokens total_cost cost_details created_at updated_at
        ].freeze

        def initialize(connection:, settings:)
          @connection = connection
          @settings = settings
        end

        def install
          unless @connection.table_exists?(TABLE)
            @connection.create_table(TABLE) do |table|
              table.string :kind, null: false
              table.string :record_id, null: false
              table.bigint :revision, null: false, default: 1
              table.index %i[kind record_id], unique: true
            end
          end
          sources.each do |kind, table|
            OPERATIONS.each { |operation| install_trigger(kind, table, operation) }
          end
        end

        def remove
          sources.each do |kind, table|
            OPERATIONS.each do |operation|
              name = trigger_name(kind, operation)
              if postgresql?
                if @connection.table_exists?(table)
                  @connection.execute("DROP TRIGGER IF EXISTS #{q(name)} ON #{qt(table)}")
                end
                @connection.execute("DROP FUNCTION IF EXISTS #{q(name)}()")
              else
                @connection.execute("DROP TRIGGER IF EXISTS #{q(name)}")
              end
            end
          end
          @connection.drop_table(TABLE) if @connection.table_exists?(TABLE)
        end

        private

        def sources
          %w[chat message tool_call model].to_h { |kind| [kind, @settings.fetch("#{kind}_table")] }
        end

        def install_trigger(kind, table, operation)
          name = trigger_name(kind, operation)
          return if trigger_exists?(name)

          body = event_sql(kind, operation)
          condition = operation == 'UPDATE' ? changed_sql(kind, table) : '1 = 1'
          state = qt(UpgradeMigration::TABLE)
          condition = "(#{condition}) AND EXISTS (SELECT 1 FROM #{state} WHERE active_version = 1)"
          sql = if postgresql?
                  <<~SQL
                    CREATE FUNCTION #{q(name)}() RETURNS trigger LANGUAGE plpgsql AS $ruby_llm$
                    BEGIN
                      IF #{condition} THEN #{body} END IF;
                      RETURN NULL;
                    END $ruby_llm$;
                    CREATE TRIGGER #{q(name)} AFTER #{operation} ON #{qt(table)}
                    FOR EACH ROW EXECUTE FUNCTION #{q(name)}();
                  SQL
                elsif mysql?
                  <<~SQL
                    CREATE TRIGGER #{q(name)} AFTER #{operation} ON #{qt(table)} FOR EACH ROW
                    BEGIN IF #{condition} THEN #{body} END IF; END
                  SQL
                else
                  <<~SQL
                    CREATE TRIGGER #{q(name)} AFTER #{operation} ON #{qt(table)} FOR EACH ROW
                    WHEN #{condition} BEGIN #{body} END
                  SQL
                end
          @connection.execute(sql)
        end

        def trigger_exists?(name)
          quoted = @connection.quote(name)
          sql = if postgresql?
                  "SELECT 1 FROM pg_trigger WHERE tgname = #{quoted} AND tgrelid IN " \
                    '(SELECT oid FROM pg_class WHERE relnamespace = current_schema()::regnamespace)'
                elsif mysql?
                  "SELECT 1 FROM information_schema.triggers WHERE trigger_name = #{quoted} " \
                    'AND trigger_schema = DATABASE()'
                else
                  "SELECT 1 FROM sqlite_master WHERE type = 'trigger' AND name = #{quoted}"
                end
          @connection.select_value(sql).present?
        end

        def changed_sql(kind, table)
          columns = @connection.columns(table).map(&:name)
          columns &= source_columns(kind) unless kind == 'tool_call'
          columns.map do |column|
            old = "OLD.#{q(column)}"
            new = "NEW.#{q(column)}"
            if postgresql?
              "#{old}::text IS DISTINCT FROM #{new}::text"
            elsif mysql?
              "NOT (CAST(#{old} AS BINARY) <=> CAST(#{new} AS BINARY))"
            else
              "#{old} IS NOT #{new}"
            end
          end.join(' OR ')
        end

        def source_columns(kind)
          primary = @connection.primary_key(sources.fetch(kind))
          case kind
          when 'chat'
            [primary, @settings.fetch('model_foreign_key')]
          when 'message'
            [primary,
             *@settings.values_at('chat_foreign_key', 'model_foreign_key', 'tool_call_foreign_key')] + MESSAGE_COLUMNS
          when 'model'
            [primary, 'provider', 'model_id']
          end
        end

        def event_sql(kind, operation)
          images = if operation == 'UPDATE'
                     %w[OLD NEW]
                   else
                     [operation == 'INSERT' ? 'NEW' : 'OLD']
                   end
          images.map do |row|
            id = event_owner(kind, row)
            event = kind == 'model' ? 'model' : 'chat'
            "INSERT INTO #{qt(TABLE)} (kind, record_id) SELECT '#{event}', #{id} WHERE #{id} IS NOT NULL #{upsert_sql};"
          end.join("\n")
        end

        def event_owner(kind, row)
          case kind
          when 'message'
            "#{row}.#{q(@settings.fetch('chat_foreign_key'))}"
          when 'tool_call'
            "(SELECT #{q(@settings.fetch('chat_foreign_key'))} FROM #{qt(sources.fetch('message'))} " \
            "WHERE #{q(@connection.primary_key(sources.fetch('message')))} = " \
            "#{row}.#{q(@settings.fetch('message_foreign_key'))})"
          else
            "#{row}.#{q(@connection.primary_key(sources.fetch(kind)))}"
          end
        end

        def upsert_sql
          return 'ON DUPLICATE KEY UPDATE revision = revision + 1' if mysql?

          "ON CONFLICT (kind, record_id) DO UPDATE SET revision = #{qt(TABLE)}.revision + 1"
        end

        def trigger_name(kind, operation) = "ruby_llm_v2_#{kind}_#{operation.downcase}"
        def postgresql? = @connection.adapter_name == 'PostgreSQL'
        def mysql? = @connection.adapter_name == 'Mysql2'
        def q(value) = @connection.quote_column_name(value)
        def qt(value) = @connection.quote_table_name(value)
      end
    end
  end
end
