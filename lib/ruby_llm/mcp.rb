# frozen_string_literal: true

module RubyLLM
  # An MCP connects your application to a Model Context Protocol server.
  # Describe the server in a subclass, the way you describe a Tool or an
  # Agent, then hand an instance to a chat:
  #
  #   class Linear < RubyLLM::MCP
  #     url "https://mcp.linear.app/mcp"
  #     inputs :user
  #     bearer_token { user.linear_token }
  #   end
  #
  #   linear = Linear.new(user: current_user)
  #   linear.tools                     # => [#<RubyLLM::MCP::Tool name: "list_issues", ...>, ...]
  #   linear.list_issues(query: "bug") # => #<RubyLLM::MCP::Result ...>
  #
  # A +url+ connects over Streamable HTTP; a +command+ starts a local
  # server that speaks over stdio:
  #
  #   class Files < RubyLLM::MCP
  #     command "npx", "-y", "@modelcontextprotocol/server-filesystem", "."
  #   end
  #
  # Settings that depend on runtime state take a block or a method name,
  # evaluated on the instance, so declared ::inputs and private methods are
  # available. RubyLLM.mcp builds one inline when a class is not worth
  # writing.
  class MCP
    include Support::Inspectable

    SETTINGS = %i[@url @command @directory @env @headers @bearer_token @timeout @input_names].freeze
    private_constant :SETTINGS

    class << self
      attr_writer :default_name # :nodoc:

      def inherited(subclass) # :nodoc:
        super
        SETTINGS.each do |setting|
          value = instance_variable_get(setting)
          subclass.instance_variable_set(setting, value.dup) unless value.nil?
        end
      end

      # Sets the server's Streamable HTTP endpoint. Plain HTTP is only
      # allowed for loopback addresses. Called with no argument, returns the
      # configured value.
      #
      #   url "https://mcp.linear.app/mcp"
      #
      def url(value = nil)
        return @url if value.nil?

        @url = value
      end

      # Sets the command that starts a local server speaking over stdio.
      # The process starts on the first request. Called with no arguments,
      # returns the configured command.
      #
      #   command "npx", "-y", "@modelcontextprotocol/server-filesystem", "."
      #
      def command(*argv)
        return @command if argv.empty?

        @command = argv.flatten
      end

      # Sets the working directory for a stdio server's process.
      #
      #   directory Rails.root
      #
      def directory(value = nil)
        return @directory if value.nil?

        @directory = value
      end

      # Adds environment variables for a stdio server's process. Values may
      # be blocks or method names. Called with no arguments, returns them.
      #
      #   env NODE_ENV: "production", API_KEY: -> { user.api_key }
      #
      def env(**variables)
        return @env || {} if variables.empty?

        @env = env.merge(variables)
      end

      # Adds an HTTP header sent with every request to the server. Pass the
      # value, a method name, or a block.
      #
      #   header "X-MCP-Toolsets", "issues,pull_requests"
      #   header("X-Account") { user.account_id }
      #
      def header(name, value = nil, &block)
        @headers = headers.merge(name.to_s => block || value)
      end

      def headers # :nodoc:
        @headers || {}
      end

      # Sets the bearer token sent in the +Authorization+ header. Pass the
      # token, a method name, or a block. Called with no argument, returns the
      # configured value.
      #
      #   bearer_token ENV.fetch("LINEAR_API_KEY")
      #   bearer_token { user.linear_token }
      #
      def bearer_token(value = nil, &block)
        return @bearer_token if value.nil? && block.nil?

        @bearer_token = block || value
      end

      # Sets how many seconds a request to the server may take. Defaults to
      # the configured +request_timeout+.
      #
      #   timeout 30
      #
      def timeout(seconds = nil)
        return @timeout if seconds.nil?

        @timeout = seconds
      end

      # Declares named inputs. Instances take them as keywords and read
      # them as methods, so blocks such as a +bearer_token+ can use them.
      # Called with no arguments, returns the declared names.
      #
      #   inputs :user
      #
      def inputs(*names)
        return @input_names || [] if names.empty?

        @input_names = names.flatten.map(&:to_sym)
        @input_names.each { |input| define_method(input) { @inputs[input] } }
      end

      def default_name # :nodoc:
        @default_name || (name && Support::Utils.underscore(name.split('::').last))
      end

      # Builds an anonymous MCP class from keywords, as RubyLLM.mcp does.
      def define(url: nil, command: nil, name: nil, bearer_token: nil, headers: {}, env: {}, directory: nil, # :nodoc:
                 timeout: nil)
        Class.new(self) do
          url(url) if url
          command(*command) if command
          headers.each { |header_name, value| header(header_name, value) }
          env(**env)
          directory(directory) if directory
          bearer_token(bearer_token) if bearer_token
          timeout(timeout) if timeout
          self.default_name = name || default_name_for(url:, command:)
        end
      end

      private

      def default_name_for(url:, command:)
        return File.basename(Array(command).first.to_s) unless url

        labels = URI(url).host.split('.')[0...-1] - %w[mcp api www]
        labels.join('_')
      end
    end

    # Creates an MCP. Keywords are the values of the declared ::inputs.
    #
    #   Linear.new(user: current_user)
    #
    # Raises ArgumentError for keywords that are not declared inputs.
    def initialize(**inputs)
      unknown = inputs.keys - self.class.inputs
      raise ArgumentError, "Unknown MCP inputs: #{unknown.join(', ')}" if unknown.any?

      @inputs = inputs
    end

    # Returns the name that identifies this MCP in a chat, derived from the
    # class name.
    #
    #   GoogleDrive.new.name # => "google_drive"
    #
    def name
      self.class.default_name
    end

    # Returns the server's tools as MCP::Tool objects, ready for a chat.
    # The list is fetched once per instance.
    def tools
      @tools ||= server_tools.map { |definition| Tool.new(self, definition) }
    end

    # Calls the server tool +name+ with +arguments+ and returns an
    # MCP::Result. Every server tool is also a method:
    #
    #   linear.call(:list_issues, query: "bug")
    #   linear.list_issues(query: "bug")
    #
    # Raises MCP::Error when the server answers with a protocol error. A
    # tool that fails returns a Result whose #error? is +true+.
    def call(name, **arguments)
      Result.new(client.request('tools/call', { name: name.to_s, arguments: }))
    end

    # Returns the instructions the server gives for using it, or +nil+.
    def instructions
      client.server['instructions']
    end

    # Returns the version the server reports for itself, or +nil+.
    def version
      server_info['version']
    end

    # Closes the connection, stopping a stdio server's process. The next
    # request reconnects.
    def close
      @client&.close
    end

    private

    def method_missing(name, *arguments, **keywords, &)
      return super unless arguments.empty? && server_tool?(name)

      call(name, **keywords)
    end

    def respond_to_missing?(name, include_private = nil)
      (@server_tools && server_tool?(name)) || super
    end

    def server_tool?(name)
      server_tools.any? { |definition| definition['name'] == name.to_s }
    end

    def server_tools
      @server_tools ||= client.list('tools/list', 'tools')
    end

    def server_info
      server = client.server
      server['serverInfo'] || server.dig('_meta', 'io.modelcontextprotocol/serverInfo') || {}
    end

    def client
      @client ||= Client.new(transport)
    end

    def transport
      settings = self.class
      if settings.url
        HTTP.new(resolve(settings.url), headers: -> { request_headers }, timeout: settings.timeout)
      elsif settings.command
        Stdio.new(settings.command.map { |part| resolve(part) },
                  env: settings.env.transform_values { |value| resolve(value) },
                  directory: resolve(settings.directory), timeout: settings.timeout)
      else
        raise ConfigurationError, "#{settings.name || 'MCP'} needs a url or a command"
      end
    end

    def request_headers
      headers = self.class.headers.transform_values { |value| resolve(value) }
      token = resolve(self.class.bearer_token)
      token ? headers.merge('Authorization' => "Bearer #{token}") : headers
    end

    def resolve(value)
      case value
      when Proc then instance_exec(&value)
      when Symbol then send(value)
      else value
      end
    end

    def inspect_attributes # :nodoc:
      { name:, url: self.class.url, command: self.class.command&.join(' ') }
    end
  end
end
