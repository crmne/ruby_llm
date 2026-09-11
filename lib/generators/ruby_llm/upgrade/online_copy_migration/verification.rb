# frozen_string_literal: true

require_relative '../legacy_content_sql'

module RubyLLM
  module Generators
    class OnlineCopyMigration < UpgradeMigration
      class Verification # :nodoc: all
        def initialize(connection:, settings:)
          @connection = connection
          @settings = settings
        end

        def verify
          verify_chats
          verify_content
          verify_usages
          verify_tools
        end

        private

        def verify_chats
          mismatch = %w[provider model_id].map do |column|
            different("copied.#{q(column)}", "original.#{q(column)}", string: true)
          end
          reject_mismatch('chat model', <<~SQL)
            SELECT c.#{pk('chat')} FROM #{table('chat')} c
            LEFT JOIN #{table('model')} original ON original.#{pk('model')} = c.#{q(@settings.fetch('model_foreign_key'))}
            LEFT JOIN #{qt(:ruby_llm_models)} copied ON copied.#{pk('model')} = c.ruby_llm_model_id
            WHERE c.ruby_llm_version = 1
              AND (original.#{pk('model')} IS NULL OR copied.#{pk('model')} IS NULL OR #{mismatch.join(' OR ')})
          SQL
        end

        def verify_content
          raw = source(:content_raw)
          rendered = LegacyContentSQL.new(@connection).render(content: "m.#{q(:content)}", raw:)
          fields = { ruby_llm_content: rendered, raw_content: raw }
          failed = fields.map do |column, expected|
            different("m.#{q(column)}", expected, json: column == :raw_content, string: true)
          end
          reject_mismatch('message content', "SELECT m.#{pk('message')} #{message_from} " \
                                             "WHERE c.ruby_llm_version = 1 AND (#{failed.join(' OR ')})")
        end

        def verify_usages
          fields = usage_fields
          eligible = fields.slice(*%i[input_tokens output_tokens cache_read_tokens cache_write_tokens thinking_tokens
                                      input_cost output_cost cache_read_cost cache_write_cost thinking_cost total_cost])
                           .values.map { |value| "#{value} IS NOT NULL" }
          eligible << "m.#{q(:role)} = 'assistant'"
          strings = %i[chat_type message_type provider model operation status]
          failed = fields.map do |column, expected|
            different("u.#{q(column)}", expected, string: strings.include?(column))
          end
          reject_mismatch('usage entry', <<~SQL)
            SELECT m.#{pk('message')} #{message_from}
            LEFT JOIN #{table('model')} cm ON cm.#{pk('model')} = c.#{q(@settings.fetch('model_foreign_key'))}
            #{message_model_join}
            LEFT JOIN #{qt(:ruby_llm_usages)} u
              ON u.legacy_key = #{copied_key(:ruby_llm_usages, "m.#{pk('message')}")}
            WHERE c.ruby_llm_version = 1 AND (#{eligible.join(' OR ')})
              AND (u.id IS NULL OR #{failed.join(' OR ')})
          SQL
        end

        def usage_fields
          fields = {
            input_tokens: source(:input_tokens), output_tokens: source(:output_tokens),
            cache_read_tokens: coalesce(source(:cache_read_tokens), source(:cached_tokens)),
            cache_write_tokens: coalesce(source(:cache_write_tokens), source(:cache_creation_tokens)),
            thinking_tokens: source(:thinking_tokens)
          }
          %w[input output cache_read cache_write thinking].each { |key| fields[:"#{key}_cost"] = cost(key) }
          fields[:total_cost] = coalesce(source(:total_cost), cost('total'))
          provider, model = model_identity
          fields.merge(chat_type: value(@settings.fetch('chat_class')), chat_id: "c.#{pk('chat')}",
                       message_type: value(@settings.fetch('message_class')), message_id: "m.#{pk('message')}",
                       provider:, model:, operation: "'chat'", status: "'succeeded'")
        end

        def model_identity
          key = @settings.fetch('model_foreign_key')
          if message_columns[key]&.type == :string
            ["COALESCE(#{source(:provider)}, cm.provider)", "COALESCE(#{source(key)}, cm.model_id)"]
          elsif message_columns.key?(key)
            ['COALESCE(mm.provider, cm.provider)', 'COALESCE(mm.model_id, cm.model_id)']
          else
            ['cm.provider', 'cm.model_id']
          end
        end

        def message_model_join
          key = @settings.fetch('model_foreign_key')
          return '' if !message_columns.key?(key) || message_columns[key].type == :string

          "LEFT JOIN #{table('model')} mm ON mm.#{pk('model')} = m.#{q(key)}"
        end

        def cost(key)
          return 'NULL' unless message_columns.key?('cost_details')

          details = source(:cost_details)
          case @connection.adapter_name
          when 'PostgreSQL' then "NULLIF(#{details}::jsonb ->> '#{key}', '')::numeric"
          when 'Mysql2'
            "CAST(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(#{details}, '$.#{key}')), 'null') AS DECIMAL(16, 10))"
          else "json_extract(#{details}, '$.#{key}')"
          end
        end

        def verify_tools
          result_type = "CASE WHEN r.#{pk('message')} IS NOT NULL THEN #{value(@settings.fetch('message_class'))} END"
          fields = { message_id: "s.#{q(@settings.fetch('message_foreign_key'))}",
                     message_type: value(@settings.fetch('message_class')), result_id: "r.#{pk('message')}",
                     result_type:,
                     tool_call_id: 's.tool_call_id', name: 's.name', arguments: 's.arguments' }
          strings = %i[message_type result_type tool_call_id name arguments]
          failed = fields.map do |column, expected|
            different("t.#{q(column)}", expected, json: column == :arguments, string: strings.include?(column))
          end
          reject_mismatch('tool call', <<~SQL)
            SELECT s.#{pk('tool_call')} FROM #{table('tool_call')} s
            LEFT JOIN #{table('message')} m ON m.#{pk('message')} = s.#{q(@settings.fetch('message_foreign_key'))}
            LEFT JOIN #{table('chat')} c ON c.#{pk('chat')} = m.#{q(@settings.fetch('chat_foreign_key'))}
            LEFT JOIN #{table('message')} r ON r.#{q(@settings.fetch('tool_call_foreign_key'))} = s.#{pk('tool_call')}
            LEFT JOIN #{qt(:ruby_llm_tool_calls)} t
              ON t.legacy_key = #{copied_key(:ruby_llm_tool_calls, "s.#{pk('tool_call')}")}
            WHERE c.ruby_llm_version = 1 AND (t.id IS NULL OR #{failed.join(' OR ')})
          SQL
        end

        def message_from
          "FROM #{table('message')} m JOIN #{table('chat')} c " \
            "ON c.#{pk('chat')} = m.#{q(@settings.fetch('chat_foreign_key'))}"
        end

        def different(left, right, json: false, string: false)
          left, right = comparable([left, right], json:, string:)
          case @connection.adapter_name
          when 'PostgreSQL' then "#{left} IS DISTINCT FROM #{right}"
          when 'Mysql2' then "NOT (#{left} <=> #{right})"
          else "#{left} IS NOT #{right}"
          end
        end

        def comparable(expressions, json:, string:)
          case @connection.adapter_name
          when 'PostgreSQL'
            json ? expressions.map { |expression| "(#{expression})::jsonb" } : expressions
          when 'Mysql2'
            string ? expressions.map { |expression| "CAST(#{expression} AS BINARY)" } : expressions
          else
            json ? expressions.map { |expression| "json(#{expression})" } : expressions
          end
        end

        def reject_mismatch(label, sql)
          id = @connection.select_value("#{sql.strip} LIMIT 1")
          raise "Record #{id} did not preserve its #{label}" if id
        end

        def text(expression) = mysql? ? "CAST(#{expression} AS BINARY)" : "CAST(#{expression} AS TEXT)"

        def copied_key(table, expression)
          return text(expression) unless mysql?

          collation = @connection.columns(table).find { |column| column.name == 'legacy_key' }.collation
          charset = collation.split('_').first
          "CAST(#{expression} AS CHAR CHARACTER SET #{q(charset)}) COLLATE #{q(collation)}"
        end

        def coalesce(*expressions)
          values = expressions.reject { |expression| expression == 'NULL' }
          return 'NULL' if values.empty?
          return values.first if values.one?

          "COALESCE(#{values.join(', ')})"
        end

        def source(column) = message_columns.key?(column.to_s) ? "m.#{q(column)}" : 'NULL'

        def message_columns
          @message_columns ||= @connection.columns(@settings.fetch('message_table')).index_by(&:name)
        end

        def mysql? = @connection.adapter_name == 'Mysql2'
        def table(kind) = qt(@settings.fetch("#{kind}_table"))
        def pk(kind) = q(@connection.primary_key(@settings.fetch("#{kind}_table")))
        def value(value) = @connection.quote(value)
        def q(value) = @connection.quote_column_name(value)
        def qt(value) = @connection.quote_table_name(value)
      end
    end
  end
end
