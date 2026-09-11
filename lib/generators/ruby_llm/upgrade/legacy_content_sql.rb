# frozen_string_literal: true

module RubyLLM
  module Generators
    class LegacyContentSQL # :nodoc: all
      SPACE = [9, 10, 11, 12, 13, 32, 133, 160, 5760, *8192..8202, 8232, 8233, 8239, 8287, 12_288].pack('U*').freeze

      def initialize(connection)
        @connection = connection
      end

      def render(content:, raw:)
        normalized, rendered, nonblank = expressions(raw)
        present = "#{normalized} NOT IN ('null', 'false', '[]', '{}') AND #{nonblank}"
        "CASE WHEN #{present} THEN #{rendered} ELSE #{content} END"
      end

      private

      def expressions(raw)
        case @connection.adapter_name
        when 'PostgreSQL'
          ["(#{raw}::jsonb)::text", "#{raw}::text",
           "btrim(#{raw}::jsonb #>> '{}', #{@connection.quote(SPACE)}) <> ''"]
        when 'Mysql2'
          ["CAST(#{raw} AS CHAR)", "CAST(#{raw} AS CHAR)",
           "JSON_UNQUOTE(#{raw}) NOT REGEXP '^[[:space:]]*$'"]
        else
          ["json(#{raw})", raw, "trim(json_extract(#{raw}, '$'), #{@connection.quote(SPACE)}) <> ''"]
        end
      end
    end
  end
end
