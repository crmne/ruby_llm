# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    module MCP
      class Server
        attr_reader :type, :config

        def initialize(type, **config)
          @type = type.to_sym
          @config = config.freeze
        end

        # Factory for stdio MCP servers
        def self.stdio(command:, args: [], env: {})
          new(:stdio, command: command, args: args, env: env)
        end

        # Factory for Ruby-native tool servers (SDK type)
        def self.ruby(tools:)
          new(:sdk, tools: tools)
        end

        def to_cli_config
          case @type
          when :stdio
            { type: 'stdio', command: @config[:command], args: @config[:args], env: @config[:env] }
          when :sdk
            { type: 'sdk', tools: @config[:tools].map(&:to_mcp_schema) }
          else
            { type: @type.to_s, **@config }
          end
        end
      end
    end
  end
end
