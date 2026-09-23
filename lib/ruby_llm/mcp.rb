# frozen_string_literal: true

module RubyLLM
  # An MCP is a client for a Model Context Protocol server. Describe the
  # server to connect to in a subclass, the way you describe a Tool or an
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

    INPUT_ROUNDS = 10
    INLINE_SETTINGS = %i[url command bearer_token directory timeout prefix].freeze

    SETTINGS = %i[
      @url @command @directory @env @headers @bearer_token @timeout @input_names
      @only @except @prefix @tool_declarations @approvals @callbacks @oauth
    ].freeze
    private_constant :SETTINGS, :INPUT_ROUNDS, :INLINE_SETTINGS

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

      # Authorizes requests with OAuth, as the MCP authorization spec
      # describes. RubyLLM discovers the server's authorization server and
      # registers itself unless you pass the +client_id:+ and
      # +client_secret:+ of an app you registered, which servers such as
      # Slack require. +owner:+ names whose credentials these are, usually an
      # input. +scopes:+ overrides the scopes the server asks for.
      #
      #   oauth owner: :user
      #   oauth owner: :user, client_id: ENV["SLACK_CLIENT_ID"], client_secret: ENV["SLACK_CLIENT_SECRET"]
      #
      # Send the user to MCP#authorization_url, then pass the callback's
      # parameters to MCP#authorize.
      def oauth(owner: nil, scopes: nil, client_id: nil, client_secret: nil)
        @oauth = { owner:, scopes:, client_id:, client_secret: }
      end

      def oauth_settings # :nodoc:
        @oauth
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

      # Limits the tools the model sees to the named server tools.
      #
      #   only :search_issues, :get_issue
      #
      def only(*names)
        return @only if names.empty?

        @only = names.flatten.map(&:to_s)
      end

      # Hides the named server tools from the model.
      #
      #   except :delete_repository
      #
      def except(*names)
        return @except || [] if names.empty?

        @except = names.flatten.map(&:to_s)
      end

      # Prefixes the names of the server's tools, so tools from servers that
      # share names, such as two servers with a +search+ tool, can join one
      # chat. Tools renamed with ::tool keep the name you gave them.
      #
      #   prefix :github   # search_issues becomes github_search_issues
      #
      def prefix(value = nil)
        return @prefix if value.nil?

        @prefix = value.to_s
      end

      # Shapes a server tool, or adds one of your own.
      #
      # Given a server tool's name, +as:+ renames it, +description:+
      # rewrites what the model reads, and +fixed_arguments:+ removes
      # arguments from the model's view and always sends your values, which
      # may be lambdas. +wrap:+ names a method that receives
      # the server's Result and the call's arguments and returns what the
      # model sees:
      #
      #   tool :search_files, as: :drive_search, description: "Search the user's Drive"
      #   tool :search_issues, fixed_arguments: { owner: "crmne", repo: "ruby_llm" }
      #   tool :read_file, wrap: :extract_text
      #
      # Given a Tool class, adds it next to the server's tools. The tool is
      # created with this MCP when its +initialize+ takes an argument, so it
      # can call the server:
      #
      #   tool SearchWithPreviews
      #
      def tool(tool, as: nil, description: nil, fixed_arguments: nil, wrap: nil)
        @tool_declarations = tool_declarations.dup
        @tool_declarations << if tool.is_a?(Class)
                                tool
                              else
                                [tool.to_s, { as:, description:, fixed_arguments:, wrap: }.compact]
                              end
      end

      def tool_declarations # :nodoc:
        @tool_declarations || []
      end

      # Pauses the named server tools for approval before they run, using
      # the flow of Tool.requires_approval. Without names, every tool needs
      # approval. +if:+ takes a Tool predicate, or a lambda that receives the
      # tool:
      #
      #   requires_approval :create_issue, :merge_pull_request
      #   requires_approval if: :destructive?
      #
      def requires_approval(*names, **options)
        unknown = options.keys - [:if]
        raise ArgumentError, "Unknown requires_approval options: #{unknown.join(', ')}" if unknown.any?

        @approvals = approvals + [[names.flatten.map(&:to_s), options[:if]]]
      end

      def approvals # :nodoc:
        @approvals || []
      end

      # Registers a callback for the progress the server reports while it
      # works on a request. Pass a method name or a block; either runs on
      # the MCP instance with an MCP::Progress.
      #
      #   after_progress :broadcast_progress
      #   after_progress { |progress| puts progress.message }
      #
      def after_progress(method = nil, &block)
        add_callback(:after_progress, method, block)
      end

      # Registers a callback for the server's requests for input from the
      # user. Pass a method name or a block; either runs on the MCP instance
      # with an MCP::InputRequest to answer or decline. In a chat, a request
      # no callback answers pauses the tool call; see Chat#pending_inputs.
      #
      #   before_input_request :ask_operator
      #   before_input_request { |request| request.answer(environment: "staging") }
      #
      def before_input_request(method = nil, &block)
        add_callback(:before_input_request, method, block)
      end

      def callbacks(name) # :nodoc:
        (@callbacks || {}).fetch(name, [])
      end

      def default_name # :nodoc:
        return @default_name if @default_name
        return Support::Utils.underscore(name.split('::').last) if name

        default_name_for(url:, command:) if url || command
      end

      # Builds an anonymous MCP class from keywords, as RubyLLM.mcp does.
      def define(name: nil, headers: {}, env: {}, oauth: nil, **settings) # :nodoc:
        unknown = settings.keys - INLINE_SETTINGS
        raise ArgumentError, "Unknown MCP settings: #{unknown.join(', ')}" if unknown.any?

        Class.new(self) do
          settings.each { |setting, value| public_send(setting, value) unless value.nil? }
          headers.each { |header_name, value| header(header_name, value) }
          env(**env)
          oauth(**(oauth == true ? {} : oauth)) if oauth
          self.default_name = name if name
        end
      end

      private

      def add_callback(name, method, block)
        raise ArgumentError, "#{name} takes a method name or a block" unless method.nil? ^ block.nil?

        @callbacks = (@callbacks || {}).merge(name => callbacks(name) + [method || block])
      end

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

    # Returns the tools the model sees: the server's tools, shaped by
    # ::only, ::except, and ::tool, followed by the Tool classes added with
    # ::tool. The server's list is fetched once per instance.
    #
    # Raises ConfigurationError when a declaration names a tool the server
    # does not offer.
    def tools
      @tools ||= begin
        check_declared_tools
        server_tools.filter_map { |definition| shape(definition) } + added_tools
      end
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
      Result.new(request('tools/call', { name: name.to_s, arguments: }))
    end

    # Returns the resources the server lists, as MCP::Resource objects
    # whose content is read when you first ask for it.
    def resources
      client.list('resources/list', 'resources').map { |data| Resource.new(self, data) }
    end

    # Reads the resource at +uri+ and returns an MCP::Resource. Given a
    # template from #resource_templates, +variables+ fill it in.
    #
    #   files.resource("file:///project/README.md")
    #   files.resource("file:///{path}", path: "Gemfile")
    #
    def resource(uri, **variables)
      uri = ResourceTemplate.expand(uri, variables) unless variables.empty?
      contents = request('resources/read', { uri: }).fetch('contents', [])
      data = contents.find { |content| content['uri'] == uri } || contents.first
      raise Error, "#{name} returned no content for #{uri}" unless data

      Resource.new(self, data)
    end

    # Returns the server's resource templates as MCP::ResourceTemplate
    # objects.
    def resource_templates
      client.list('resources/templates/list', 'resourceTemplates').map { |data| ResourceTemplate.new(self, data) }
    end

    # Returns the prompts the server offers, as MCP::Prompt objects.
    def prompts
      client.list('prompts/list', 'prompts').map { |data| Prompt.new(self, data) }
    end

    # Fills in the server prompt +name+ with +arguments+ and returns an
    # MCP::Prompt with its messages, ready for Chat#ask.
    #
    #   chat.ask github.prompt(:code_review, code: diff)
    #
    def prompt(name, **arguments)
      result = request('prompts/get', { name: name.to_s, arguments: arguments.transform_values(&:to_s) })
      messages = result.fetch('messages', []).map do |message|
        content, attachments = Content.read([message['content']])
        Message.new(role: message['role'].to_sym, content:, attachments:)
      end
      Prompt.new(self, { 'name' => name.to_s, 'description' => result['description'] }, messages:)
    end

    # Asks the server to complete the first of +values+ for +reference+,
    # with the rest as context.
    def suggest(reference, values) # :nodoc:
      (argument, value), *filled = values.to_a
      raise ArgumentError, 'Pass the value to complete as a keyword' unless argument

      params = { ref: reference, argument: { name: argument.to_s, value: value.to_s } }
      params[:context] = { arguments: filled.to_h { |key, filler| [key.to_s, filler.to_s] } } if filled.any?
      client.request('completion/complete', params).dig('completion', 'values') || []
    end

    # Returns whether +tool+, one of this MCP's tools, needs approval
    # according to ::requires_approval.
    def requires_approval?(tool) # :nodoc:
      self.class.approvals.any? do |names, condition|
        next false unless names.empty? || names.include?(tool.server_name)

        condition.nil? || (condition.is_a?(Proc) ? instance_exec(tool, &condition) : tool.public_send(condition))
      end
    end

    # Runs +tool+, one of this MCP's tools, with the model's +arguments+.
    def run(tool, arguments, input: nil) # :nodoc:
      arguments = arguments.transform_keys(&:to_sym)
      fixed = tool.fixed_arguments.transform_values { |value| value.is_a?(Proc) ? instance_exec(&value) : value }
      params = { name: tool.server_name, arguments: arguments.merge(fixed) }
      result = Result.new(request('tools/call', params, input:))
      return { error: result.text } if result.error?

      tool.wrap ? apply(tool.wrap, result, **arguments) : result.content
    end

    # Returns the instructions the server gives for using it, or +nil+.
    def instructions
      client.server['instructions']
    end

    # Returns the version the server reports for itself, or +nil+.
    def version
      server_info['version']
    end

    # Returns whether the owner has authorized this server. Only for
    # servers declared with ::oauth.
    def authorized?
      oauth.authorized?
    end

    # Returns the URL to send the user to so they can authorize this
    # server. The authorization server redirects back to +redirect_uri+,
    # whose parameters go to #authorize.
    #
    #   redirect_to linear.authorization_url(redirect_uri: mcp_callback_url), allow_other_host: true
    #
    def authorization_url(redirect_uri:)
      oauth.authorization_url(redirect_uri:, challenge: @challenge || challenge)
    end

    # Completes an authorization with the parameters of the callback
    # request, such as a controller's +params+. Returns +self+.
    #
    #   Linear.new(user: current_user).authorize(params)
    #
    # Raises MCP::Error when the callback does not match the authorization
    # that #authorization_url started.
    def authorize(params)
      oauth.authorize(params)
      self
    end

    # Forgets the owner's credentials for this server. Returns +self+.
    def deauthorize
      oauth.deauthorize
      self
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

    def request(method, params, input: nil)
      result = input ? send_answers(method, params, input) : send_request(method, params)
      INPUT_ROUNDS.times do
        return result unless result['resultType'] == 'input_required'

        input = { 'requests' => input_requests(result), 'request_state' => result['requestState'] }
        raise InputRequiredError.new(name, input) unless input['requests'].all?(&:answered?)

        result = send_answers(method, params, input)
      end
      raise Error, "#{name} kept asking for input"
    end

    def send_answers(method, params, input)
      requests = input['requests'].map { |request| request.is_a?(Hash) ? InputRequest.from_h(request) : request }
      responses = requests.to_h { |request| [request.key, request.response] }
      send_request(method, params.merge({ inputResponses: responses, requestState: input['request_state'] }.compact))
    end

    def input_requests(result)
      result.fetch('inputRequests', {}).filter_map do |key, request|
        next unless request['method'] == 'elicitation/create'

        InputRequest.new(key, request['params'] || {}).tap do |input_request|
          self.class.callbacks(:before_input_request).each do |callback|
            apply(callback, input_request) unless input_request.answered?
          end
        end
      end
    end

    def send_request(method, params)
      headers = method == 'tools/call' ? mirrored_headers(params) : {}
      callbacks = self.class.callbacks(:after_progress)
      return client.request(method, params, headers:) if callbacks.empty?

      token = SecureRandom.uuid
      client.request(method, params.merge(_meta: { progressToken: token }), headers:) do |notification|
        next unless notification['method'] == 'notifications/progress'
        next unless notification.dig('params', 'progressToken') == token

        progress = Progress.new(notification['params'])
        callbacks.each { |callback| apply(callback, progress) }
      end
    end

    def mirrored_headers(params)
      definition = server_tools.find { |tool| tool['name'] == params[:name] }
      definition ? ParamHeaders.for(definition, params[:arguments]) : {}
    end

    def shape(definition)
      name = definition['name']
      only = self.class.only
      return if (only && !only.include?(name)) || self.class.except.include?(name)

      options = self.class.tool_declarations.select { |declaration| declaration.is_a?(Array) && declaration[0] == name }
                    .map(&:last).reduce({}, :merge)
      Tool.new(self, definition, prefix: self.class.prefix, **options)
    end

    def added_tools
      self.class.tool_declarations.grep(Class).map do |tool|
        tool.instance_method(:initialize).arity.zero? ? tool.new : tool.new(self)
      end
    end

    def check_declared_tools
      declared = Array(self.class.only) + self.class.approvals.flat_map(&:first) +
                 self.class.tool_declarations.grep(Array).map(&:first)
      missing = declared.uniq - server_tools.map { |definition| definition['name'] }
      return if missing.empty?

      raise ConfigurationError, "#{name} declares #{missing.join(', ')}, which the server does not offer"
    end

    def apply(callable, *arguments, **keywords)
      callable.is_a?(Proc) ? instance_exec(*arguments, **keywords, &callable) : send(callable, *arguments, **keywords)
    end

    def server_tool?(name)
      server_tools.any? { |definition| definition['name'] == name.to_s }
    end

    def server_tools
      @server_tools ||= client.list('tools/list', 'tools').select { |definition| ParamHeaders.valid?(definition) }
    end

    def server_info
      server = client.server
      server['serverInfo'] || server.dig('_meta', 'io.modelcontextprotocol/serverInfo') || {}
    end

    def client
      @client ||= Client.new(transport, capabilities: { elicitation: { form: {}, url: {} } })
    end

    def transport
      settings = self.class
      if settings.url
        HTTP.new(resolve(settings.url), headers: -> { request_headers }, timeout: settings.timeout,
                                        unauthorized: method(:unauthorized))
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
      token = self.class.oauth_settings ? oauth.access_token : resolve(self.class.bearer_token)
      token ? headers.merge('Authorization' => "Bearer #{token}") : headers
    end

    def oauth
      settings = self.class.oauth_settings or raise ConfigurationError, "#{name} does not use OAuth"
      owner = resolve(settings[:owner])
      raise ArgumentError, "#{name} needs an owner for OAuth credentials" if settings[:owner] && owner.nil?

      @oauth ||= OAuth.new(resolve(self.class.url), owner:, scopes: settings[:scopes],
                                                    client_id: resolve(settings[:client_id]),
                                                    client_secret: resolve(settings[:client_secret]))
    end

    def unauthorized(headers, status)
      @challenge = OAuth.challenge(headers['www-authenticate'] || headers['WWW-Authenticate'])
      status == 401 && self.class.oauth_settings && oauth.authorized? && oauth.refresh
    end

    def challenge
      client.server
      nil
    rescue UnauthorizedError
      @challenge
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
