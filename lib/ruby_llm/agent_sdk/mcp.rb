# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    # Model Context Protocol (MCP) server configuration
    #
    # MCP servers extend Claude's capabilities by providing additional
    # tools, resources, and prompts. This module supports all MCP
    # transport types: stdio, SSE, HTTP, and SDK.
    #
    # @example Stdio server (npx-based)
    #   server = MCP::Server.stdio(
    #     'filesystem',
    #     command: 'npx',
    #     args: ['-y', '@anthropic/mcp-server-filesystem', '/tmp']
    #   )
    #
    # @example HTTP server
    #   server = MCP::Server.http(
    #     'api-server',
    #     url: 'http://localhost:8080/mcp'
    #   )
    module MCP
      # Transport types supported by Claude CLI
      TRANSPORTS = %i[stdio sse http sdk].freeze

      # MCP Server configuration
      #
      # Represents a single MCP server that can be passed to Claude CLI.
      class Server
        attr_reader :name, :transport, :config

        # @param name [String, Symbol] Server identifier
        # @param transport [Symbol] Transport type (:stdio, :sse, :http, :sdk)
        # @param config [Hash] Transport-specific configuration
        def initialize(name:, transport:, **config)
          @name = name.to_s
          @transport = transport.to_sym
          @config = config

          validate!
        end

        # Create a stdio transport server
        #
        # @param name [String] Server name
        # @param command [String] Command to execute
        # @param args [Array<String>] Command arguments
        # @param env [Hash] Environment variables
        # @return [Server]
        def self.stdio(name, command:, args: [], env: {})
          new(
            name: name,
            transport: :stdio,
            command: command,
            args: args,
            env: env
          )
        end

        # Create an SSE transport server
        #
        # @param name [String] Server name
        # @param url [String] SSE endpoint URL
        # @return [Server]
        def self.sse(name, url:)
          new(
            name: name,
            transport: :sse,
            url: url
          )
        end

        # Create an HTTP transport server
        #
        # @param name [String] Server name
        # @param url [String] HTTP endpoint URL
        # @return [Server]
        def self.http(name, url:)
          new(
            name: name,
            transport: :http,
            url: url
          )
        end

        # Create an SDK transport server (embedded tools)
        #
        # @param name [String] Server name
        # @param tools [Array<Tool>] Tools to expose
        # @return [Server]
        def self.sdk(name, tools:)
          new(
            name: name,
            transport: :sdk,
            tools: tools
          )
        end

        # Get the command for stdio transport
        #
        # @return [String, nil]
        def command
          config[:command]
        end

        # Get the args for stdio transport
        #
        # @return [Array<String>]
        def args
          config[:args] || []
        end

        # Get the URL for sse/http transport
        #
        # @return [String, nil]
        def url
          config[:url]
        end

        # Get environment variables
        #
        # @return [Hash]
        def env
          config[:env] || {}
        end

        # Get tools for SDK transport
        #
        # @return [Array<Tool>]
        def tools
          config[:tools] || []
        end

        # Convert to hash for CLI configuration
        #
        # @return [Hash]
        def to_h
          base = { type: transport.to_s }

          case transport
          when :stdio
            base.merge(
              command: command,
              args: args,
              env: env.transform_keys(&:to_s)
            )
          when :sse, :http
            base.merge(url: url)
          when :sdk
            base.merge(tools: tools.map(&:to_h))
          else
            base.merge(config)
          end
        end

        # Convert to JSON for .mcp.json file
        #
        # @return [String]
        def to_json(*args)
          to_h.to_json(*args)
        end

        private

        def validate!
          unless TRANSPORTS.include?(transport)
            raise ConfigurationError, "Invalid transport: #{transport}. Must be one of: #{TRANSPORTS.join(', ')}"
          end

          case transport
          when :stdio
            raise ConfigurationError, 'stdio transport requires command' unless command
          when :sse, :http
            raise ConfigurationError, "#{transport} transport requires url" unless url
          when :sdk
            raise ConfigurationError, 'sdk transport requires tools' unless config[:tools]
          end
        end
      end

      # Collection of MCP servers for an agent
      #
      # @example Configure multiple servers
      #   servers = MCP::Servers.new
      #   servers.add MCP::Server.stdio('fs', command: 'npx', args: [...])
      #   servers.add MCP::Server.http('api', url: 'http://...')
      class Servers
        include Enumerable

        def initialize
          @servers = {}
        end

        # Add a server
        #
        # @param server [Server] Server to add
        # @return [Server]
        def add(server)
          @servers[server.name] = server
          server
        end
        alias << add

        # Get a server by name
        #
        # @param name [String, Symbol] Server name
        # @return [Server, nil]
        def [](name)
          @servers[name.to_s]
        end

        # Check if a server exists
        #
        # @param name [String, Symbol] Server name
        # @return [Boolean]
        def include?(name)
          @servers.key?(name.to_s)
        end

        # Iterate over all servers
        #
        # @yield [Server]
        def each(&block)
          @servers.values.each(&block)
        end

        # Get all server names
        #
        # @return [Array<String>]
        def names
          @servers.keys
        end

        # Get count of servers
        #
        # @return [Integer]
        def size
          @servers.size
        end

        # Convert to hash for CLI configuration
        #
        # @return [Hash]
        def to_h
          @servers.transform_values(&:to_h)
        end

        # Generate .mcp.json content
        #
        # @return [Hash]
        def to_mcp_json
          { mcpServers: to_h }
        end
      end
    end
  end
end
