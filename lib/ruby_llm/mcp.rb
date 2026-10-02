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
  # A +transport+ carries the messages any other way, such as through a
  # tunnel to a server behind a firewall.
  #
  # Settings that depend on runtime state take a block or a method name,
  # evaluated on the instance, so declared ::inputs and private methods are
  # available. RubyLLM.mcp builds one inline when a class is not worth
  # writing.
  class MCP
    include Support::Inspectable

    INPUT_ROUNDS = 10
    INPUT_REQUESTS = %i[form url].freeze
    INLINE_SETTINGS = %i[url command transport bearer_token directory timeout prefix input_requests log_level].freeze
    LOG_LEVELS = {
      debug: Logger::DEBUG, info: Logger::INFO, notice: Logger::INFO, warning: Logger::WARN,
      error: Logger::ERROR, critical: Logger::FATAL, alert: Logger::FATAL, emergency: Logger::FATAL
    }.freeze
    EXTENSIONS = {
      apps: [Apps::EXTENSION, { 'mimeTypes' => [Apps::MIME_TYPE] }],
      tasks: ['io.modelcontextprotocol/tasks', {}]
    }.freeze
    POLL_INTERVAL = 1
    UNKNOWN_TOOL_ERRORS = [-32_601, -32_602].freeze

    SETTINGS = %i[
      @url @command @directory @env @headers @bearer_token @timeout @input_names
      @only @except @prefix @tool_declarations @approvals @callbacks @oauth @input_requests @extensions @log_level
    ].freeze
    private_constant :SETTINGS, :INPUT_ROUNDS, :INPUT_REQUESTS, :INLINE_SETTINGS, :EXTENSIONS, :POLL_INTERVAL,
                     :LOG_LEVELS, :UNKNOWN_TOOL_ERRORS

    class << self
      attr_writer :default_name # :nodoc:

      def inherited(subclass) # :nodoc:
        super
        SETTINGS.each do |setting|
          value = instance_variable_get(setting)
          subclass.instance_variable_set(setting, value.dup) unless value.nil?
        end
        subclass.transport(@transport) if @transport
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

      # Sets the transport that carries the server's JSON-RPC messages, for
      # servers reached neither over Streamable HTTP nor over stdio. Pass
      # the transport, a method name, or a block that returns one. Called
      # with no argument, returns the configured value.
      #
      #   transport { Tunnel.new(device) }
      #
      # A transport responds to four methods.
      # <tt>request(message, version:, timeout:, headers:)</tt> sends a
      # JSON-RPC request and returns the response as a Hash with string
      # keys, yielding any notifications the server sends meanwhile.
      # +timeout+ is +nil+ unless RubyLLM needs a shorter one than the
      # transport's own, and +headers+ holds the tool arguments the server
      # asks to receive as <tt>Mcp-Param-*</tt> HTTP headers.
      # <tt>notify(message, version:)</tt> and
      # <tt>cancel(notification, version:)</tt> send a notification, and
      # +close+ releases the connection until the next request. Raise
      # MCP::Error when the server cannot be reached. The transport handles
      # its own authentication and timeouts.
      def transport(value = nil, &block)
        return @transport if value.nil? && block.nil?

        @transport = block || value
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
      # Slack require. Those only go to the authorization server they were
      # first used with. +owner:+ names whose credentials these are, usually
      # an input. +scopes:+ overrides the scopes the server asks for.
      #
      #   oauth owner: :user
      #   oauth owner: :user, client_id: ENV["SLACK_CLIENT_ID"], client_secret: ENV["SLACK_CLIENT_SECRET"]
      #
      # Send the user to MCP#authorization_url, then pass the callback's
      # parameters to MCP#authorize. Servers that require DPoP get tokens
      # bound to a key that RubyLLM keeps with the credentials.
      #
      # +grant: :client_credentials+ connects your app as itself, with no
      # user: RubyLLM requests a token when the server first asks for one
      # and a new one before it expires. +private_key:+, a PEM string or an
      # OpenSSL key, signs a short-lived assertion in place of
      # +client_secret:+, for any app you registered.
      #
      #   oauth grant: :client_credentials, client_id: "reports", private_key: ENV["REPORTS_PRIVATE_KEY"]
      #
      # +assertion:+ presents a JWT your platform issued, such as a
      # Kubernetes service account token, with the JWT bearer grant
      # (+grant: :jwt_bearer+), so a workload needs no credentials of its
      # own. A block or method name is read for every token, as platforms
      # rotate them.
      #
      #   oauth assertion: -> { File.read("/var/run/secrets/tokens/mcp-token") }
      #
      # +identity_provider:+ authorizes the users who sign in to your app
      # through their company's identity provider, with no consent screen:
      # RubyLLM exchanges the user's ID token for a grant the server's
      # authorization server accepts, as the identity provider's policy
      # allows. Pass its +issuer:+, your app's +client_id:+ and
      # +client_secret:+ there, and the user's +id_token:+. Values may be
      # blocks or method names.
      #
      #   oauth owner: :user, client_id: ENV["WIKI_CLIENT_ID"], client_secret: ENV["WIKI_CLIENT_SECRET"],
      #         identity_provider: { issuer: "https://acme.okta.com", client_id: ENV["OKTA_CLIENT_ID"],
      #                              client_secret: ENV["OKTA_CLIENT_SECRET"], id_token: -> { user.id_token } }
      def oauth(owner: nil, scopes: nil, client_id: nil, client_secret: nil, grant: nil, private_key: nil,
                assertion: nil, identity_provider: nil)
        raise ArgumentError, "Unknown OAuth grant: #{grant}" unless grant.nil? || OAuth::GRANTS.include?(grant)

        @oauth = { owner:, scopes:, client_id:, client_secret:, grant:, private_key:, assertion:, identity_provider: }
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
      # the MCP instance with a Progress. In a chat, the progress of a tool
      # call also reaches Chat#after_tool_progress.
      #
      #   after_progress :broadcast_progress
      #   after_progress { |progress| puts progress.message }
      #
      def after_progress(method = nil, &block)
        add_callback(:after_progress, method, block)
      end

      # Registers a callback for the changes the server announces. Pass a
      # method name or a block; either runs on the MCP instance with what
      # changed: +:tools+, +:prompts+, or +:resources+ when the server's
      # list of them changes, the MCP::Resource whose content changed, or
      # the MCP::Task whose status changed. RubyLLM has already forgotten
      # the old tools when +:tools+ arrives.
      #
      #   after_change :refresh
      #   after_change { |change| Rails.cache.delete("handbook/tools") if change == :tools }
      #
      # Servers that predate 2026-07-28 announce changes as they answer a
      # request; the callback runs once the request is answered. Newer
      # servers announce them only while the MCP listens; see #listen.
      # Changes made while a listener reconnects are lost, so once it is
      # back, the callback runs for everything it listens to.
      def after_change(method = nil, &block)
        add_callback(:after_change, method, block)
      end

      # Sets the kinds of requests for input the server may send: +:form+,
      # +:url+, or both, the default. Pass +false+ when your app cannot
      # show them to anyone, so a call never waits on an answer that will
      # not come. RubyLLM declines requests of other kinds. Called with no
      # arguments, returns the accepted kinds.
      #
      #   input_requests false
      #   input_requests :url
      #
      def input_requests(*kinds)
        return @input_requests || INPUT_REQUESTS if kinds.empty?

        kinds = (kinds.flatten - [false, nil]).map(&:to_sym)
        unknown = kinds - INPUT_REQUESTS
        raise ArgumentError, "Unknown input requests: #{unknown.join(', ')}" if unknown.any?

        @input_requests = kinds
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

      # Declares an extension to the protocol that your app supports, so
      # servers can use it. +settings+ belong to the extension and go to
      # the server as written. Extensions are named with a vendor prefix.
      #
      #   extension "com.example/audit", level: "full"
      #
      # RubyLLM implements two extensions you declare by name. With
      # +:apps+, MCP Apps, tools come with a UI your app renders next to
      # their results, and tools that only a UI may call stay out of chats;
      # see MCP::Tool#visibility. With +:tasks+, a server may run a long
      # tool call in the background; see MCP::Task.
      #
      #   extension :apps
      #   extension :tasks
      #
      # RubyLLM declares extensions in the capabilities of every request,
      # and when it connects to a server that predates 2026-07-28.
      #
      # Raises ArgumentError for a name without a vendor prefix, or a
      # Symbol RubyLLM does not know.
      def extension(name, **settings)
        name, defaults = extension_identifier(name)
        @extensions = extensions.merge(name => defaults.merge(settings.transform_keys(&:to_s)))
      end

      def extensions # :nodoc:
        @extensions || {}
      end

      # Asks the server for the log messages it writes while it works on a
      # request, at +level+ and above, and writes them to the RubyLLM
      # logger. The levels are the protocol's, from +:debug+ through
      # +:info+, +:notice+, +:warning+, +:error+, +:critical+, and +:alert+
      # to +:emergency+. Without a level, servers send no log messages.
      # Called with no argument, returns the level.
      #
      #   log_level :warning
      #
      # Raises ArgumentError for a level the protocol does not define.
      def log_level(level = nil)
        return @log_level if level.nil?
        raise ArgumentError, "Unknown MCP log level: #{level}" unless LOG_LEVELS.key?(level.to_sym)

        @log_level = level.to_sym
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
      def define(name: nil, headers: {}, env: {}, oauth: nil, extensions: nil, **settings) # :nodoc:
        check_inline_settings(name, settings)

        Class.new(self) do
          settings.each { |setting, value| public_send(setting, value) unless value.nil? }
          headers.each { |header_name, value| header(header_name, value) }
          Array(extensions).each { |extension_name, options| extension(extension_name, **options.to_h) }
          env(**env)
          oauth(**(oauth == true ? {} : oauth)) if oauth
          self.default_name = name if name
        end
      end

      private

      def check_inline_settings(name, settings)
        unknown = settings.keys - INLINE_SETTINGS
        raise ArgumentError, "Unknown MCP settings: #{unknown.join(', ')}" if unknown.any?
        raise ArgumentError, 'An MCP with a transport needs a name' if settings[:transport] && name.nil?
      end

      def extension_identifier(name)
        return EXTENSIONS.fetch(name) { raise ArgumentError, "Unknown MCP extension: #{name}" } if name.is_a?(Symbol)
        return [name.to_s, {}] if name.to_s.include?('/')

        raise ArgumentError, "MCP extensions are named with a vendor prefix, such as com.example/#{name}"
      end

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
    # Pass a Context as +context:+ to connect with its configuration: its
    # +faraday_adapter+, +http_proxy+, and +request_timeout+ apply to the
    # server's requests and to its OAuth requests.
    #
    #   Linear.new(user: current_user)
    #   Linear.new(user: current_user, context: RubyLLM.context { |config| config.http_proxy = proxy })
    #
    # Raises ArgumentError for keywords that are not declared inputs.
    def initialize(context: nil, **inputs)
      unknown = inputs.keys - self.class.inputs
      raise ArgumentError, "Unknown MCP inputs: #{unknown.join(', ')}" if unknown.any?

      @context = context
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

    # Returns the server's tools, shaped by ::only, ::except, and ::tool,
    # followed by the Tool classes added with ::tool. The server's list is
    # fetched once, and again after the server says it changed or answers
    # a call with an error because the tool is gone.
    #
    # The list includes the tools of an MCP App that only its UI may call,
    # whose MCP::Tool#visibility leaves out +:model+. Chats never offer
    # those to the model.
    #
    # Raises ConfigurationError when a declaration names a tool the server
    # does not offer.
    def tools
      @tools || remember(:@tools) do
        definitions = server_tools
        check_declared_tools(definitions)
        definitions.filter_map { |definition| shape(definition) } + added_tools
      end
    end

    # Calls the server tool +name+ with +arguments+ and returns an
    # MCP::Result. Every server tool is also a method:
    #
    #   linear.call(:list_issues, query: "bug")
    #   linear.list_issues(query: "bug")
    #
    # When the server runs the call as a task, waits for it the way
    # MCP::Task#wait does, and cancels it if waiting fails.
    #
    # Raises MCP::Error when the server answers with a protocol error. A
    # tool that fails returns a Result whose #error? is +true+.
    def call(name, **arguments)
      outcome = call_tool({ name: name.to_s, arguments: })
      Result.new(outcome.is_a?(Task) ? finish(outcome) : outcome, ui_uri_of(name))
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
      outcome = call_tool(params, input:)
      return outcome if outcome.is_a?(Task)

      result = Result.new(outcome, tool.ui_uri)
      return { error: result.text } if result.error?

      tool.wrap ? apply(tool.wrap, result, **arguments) : result
    end

    # Checks on the task +id+ once and returns its state, reporting what it
    # is doing as progress.
    def poll_task(id) # :nodoc:
      data = client.request('tasks/get', { taskId: id })
      message = data['statusMessage']
      if message && %w[working input_required].include?(data['status'])
        progress_listeners.each { |listener| listener.call(Progress.new(message:)) }
      end
      data
    end

    # Asks the server to cancel the task +id+.
    def cancel_task(id) # :nodoc:
      client.request('tasks/cancel', { taskId: id })
    end

    # Checks on +task+ until it is done, as MCP::Task#wait describes.
    def await_task(task, timeout: nil, interval: nil) # :nodoc:
      limit = timeout || self.class.timeout || config.request_timeout
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + limit
      until task.done?
        ask_for_task_input(task) if task.status == :input_required
        remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        raise Error, "Task #{task.id} did not finish in #{limit} seconds" unless remaining.positive?

        Support::Cancellation.pause([interval || poll_interval(task), remaining].min)
        task.refresh
      end
      raise task.error unless task.completed?

      task
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

    # Listens for the server's changes in a background thread until
    # #close, so ::after_change callbacks run as changes happen and #tools
    # follows the server's list. Pass +resources+, as URIs or
    # MCP::Resource objects, to hear when their content changes, and
    # +tasks+, as MCP::Task objects or their IDs, to hear when their status
    # changes; a later call replaces them. Returns +self+ once the server
    # confirms.
    #
    #   handbook = Handbook.new.listen(resources: ["handbook://policies"])
    #   reports.listen(tasks: chat.pending_tasks)
    #
    # Without +resources+ or +tasks+, does nothing for a server that
    # announces no changes. Raises MCP::Error when the server cannot be
    # reached or does not send updates for the resources or tasks.
    def listen(resources: [], tasks: [])
      uris = resources.map { |resource| resource.respond_to?(:uri) ? resource.uri : resource.to_s }
      ids = tasks.map { |task| task.respond_to?(:id) ? task.id : task.to_s }
      watched = listener.start(listened_changes(uris, ids)) || {}
      missing = (uris - Array(watched['resourceSubscriptions'])) + (ids - Array(watched['taskIds']))
      return self if missing.empty?

      listener.stop
      raise Error, "#{name} does not send updates for #{missing.join(', ')}"
    end

    # Closes the connection, stopping a stdio server's process and ending
    # the session of a server that keeps one, and stops listening. The next
    # request reconnects.
    def close
      @listener&.stop
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

        input = { 'requests' => requests_for_input(result), 'request_state' => result['requestState'] }
        raise InputRequiredError.new(name, input) unless input['requests'].all?(&:answered?)

        result = send_answers(method, params, input)
      end
      raise Error, "#{name} kept asking for input"
    end

    def send_answers(method, params, input)
      responses = responses(input['requests'])
      send_request(method, params.merge({ inputResponses: responses, requestState: input['request_state'] }.compact))
    end

    def responses(requests)
      requests.to_h do |request|
        request = InputRequest.from_h(request) if request.is_a?(Hash)
        [request.key, request.response]
      end
    end

    def call_tool(params, input: nil)
      return check_task(Task.load(self, input), input['requests']) if input&.key?('task')

      data = request_tool(params, input:)
      data['resultType'] == 'task' ? Task.new(self, data) : data
    end

    def request_tool(params, input:)
      request('tools/call', params, input:)
    rescue Error => e
      forget_tools if UNKNOWN_TOOL_ERRORS.include?(e.code)
      raise
    end

    def check_task(task, answered_requests)
      update_task(task, answered_requests) if answered_requests
      task.refresh
      return task.data['result'] if task.completed?
      raise task.error if task.done?

      ask_for_task_input(task) if task.status == :input_required
      task
    end

    def ask_for_task_input(task)
      requests = requests_for_input('inputRequests' => task.data.fetch('inputRequests', {}).except(*task.answered))
      return if requests.empty?
      raise InputRequiredError.new(name, task.to_h.merge('requests' => requests)) unless requests.all?(&:answered?)

      update_task(task, requests)
    end

    def update_task(task, requests)
      responses = responses(requests)
      client.request('tasks/update', { taskId: task.id, inputResponses: responses })
      task.record_answers(responses.keys)
    end

    def poll_interval(task)
      task.poll_interval || POLL_INTERVAL
    end

    def finish(task)
      task.wait.data['result']
    rescue StandardError
      begin
        task.cancel
      rescue Error, Faraday::Error => e
        RubyLLM.logger.debug { "#{name} could not cancel task #{task.id}: #{e.message}" }
      end
      raise
    end

    def requests_for_input(result)
      result.fetch('inputRequests', {}).filter_map do |key, request|
        next unless request['method'] == 'elicitation/create'

        InputRequest.new(key, request['params'] || {}).tap do |input_request|
          next input_request.decline unless accepts?(input_request)

          self.class.callbacks(:before_input_request).each do |callback|
            apply(callback, input_request) unless input_request.answered?
          end
        end
      end
    end

    def accepts?(input_request)
      self.class.input_requests.include?(input_request.url? ? :url : :form)
    end

    def send_request(method, params)
      headers = method == 'tools/call' ? mirrored_headers(params) : {}
      listeners = progress_listeners
      level = self.class.log_level
      return client.request(method, params, headers:) if listeners.empty? && level.nil?

      token = SecureRandom.uuid unless listeners.empty?
      meta = { progressToken: token, 'io.modelcontextprotocol/logLevel' => level&.to_s }.compact
      client.request(method, params.merge(_meta: meta), headers:) do |notification|
        data = notification['params'] || {}
        case notification['method']
        when 'notifications/progress' then report_progress(data, token, listeners)
        when 'notifications/message' then log(data, level)
        end
      end
    end

    def report_progress(data, token, listeners)
      return unless token && data['progressToken'] == token

      progress = Progress.new(value: data['progress'], total: data['total'], message: data['message'])
      listeners.each { |listener| listener.call(progress) }
    end

    def log(data, minimum)
      level = data['level'].to_s.to_sym
      return unless minimum && LOG_LEVELS.key?(level) && LOG_LEVELS.keys.index(level) >= LOG_LEVELS.keys.index(minimum)

      text = data['data'].is_a?(String) ? data['data'] : JSON.generate(data['data'])
      RubyLLM.logger.add(LOG_LEVELS[level], "#{name}#{" (#{data['logger']})" if data['logger']}: #{text}")
    end

    def progress_listeners
      listeners = self.class.callbacks(:after_progress).map { |callback| ->(progress) { apply(callback, progress) } }
      [*listeners, Support::ProgressReporter.listener].compact
    end

    def mirrored_headers(params)
      definition = server_tool(params[:name])
      definition ? ParamHeaders.for(definition, params[:arguments]) : {}
    end

    def ui_uri_of(name)
      definition = server_tool(name)
      Apps.uri(definition['_meta'] || {}) if definition
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

    def check_declared_tools(definitions)
      declared = Array(self.class.only) + self.class.approvals.flat_map(&:first) +
                 self.class.tool_declarations.grep(Array).map(&:first)
      missing = declared.uniq - definitions.map { |definition| definition['name'] }
      return if missing.empty?

      raise ConfigurationError, "#{name} declares #{missing.join(', ')}, which the server does not offer"
    end

    def apply(callable, *, **keywords)
      callable.is_a?(Proc) ? instance_exec(*, **keywords, &callable) : send(callable, *, **keywords)
    end

    def server_tool?(name)
      !server_tool(name).nil?
    end

    def server_tool(name)
      server_tools.find { |definition| definition['name'] == name.to_s }
    end

    def server_tools
      @server_tools || remember(:@server_tools) do
        client.list('tools/list', 'tools').select { |definition| ParamHeaders.valid?(definition) }
      end
    end

    def remember(variable)
      changes = @tool_changes
      value = yield
      instance_variable_set(variable, value) if changes == @tool_changes
      value
    end

    def changed(notification)
      case notification['method']
      when Client::ACKNOWLEDGED then forget_tools
      when 'notifications/tools/list_changed'
        forget_tools
        announce(:tools)
      when 'notifications/prompts/list_changed' then announce(:prompts)
      when 'notifications/resources/list_changed' then announce(:resources)
      when 'notifications/resources/updated'
        announce(Resource.new(self, 'uri' => notification.dig('params', 'uri')))
      when 'notifications/tasks' then announce(Task.new(self, notification['params'].except('_meta')))
      end
    end

    def forget_tools
      @tool_changes = @tool_changes.to_i + 1
      @tools = @server_tools = nil
    end

    def announce(change)
      self.class.callbacks(:after_change).each { |callback| apply(callback, change) }
    end

    def listener
      @listener ||= Listener.new(client, name:, timeout: self.class.timeout || config.request_timeout,
                                         resumed: method(:caught_up)) { |notification| changed(notification) }
    end

    def caught_up(listened)
      %i[tools prompts resources].each { |list| announce(list) if listened["#{list}ListChanged"] }
      Array(listened['resourceSubscriptions']).each { |uri| announce(Resource.new(self, 'uri' => uri)) }
      Array(listened['taskIds']).each { |id| announce(Task.new(self, poll_task(id))) }
    end

    def listened_changes(uris, ids)
      capabilities = client.server['capabilities'] || {}
      changes = %w[tools prompts resources].each_with_object({}) do |list, listened|
        listened[:"#{list}ListChanged"] = true if capabilities.dig(list, 'listChanged')
      end
      changes[:resourceSubscriptions] = uris unless uris.empty?
      changes[:taskIds] = ids unless ids.empty?
      changes
    end

    def server_info
      server = client.server
      server['serverInfo'] || server.dig('_meta', 'io.modelcontextprotocol/serverInfo') || {}
    end

    def client
      @client ||= Client.new(transport, capabilities:) { |notification| changed(notification) }
    end

    def capabilities
      kinds = self.class.input_requests
      extensions = OAuth.extensions(self.class.oauth_settings).merge(self.class.extensions)
      capabilities = kinds.empty? ? {} : { elicitation: kinds.to_h { |kind| [kind, {}] } }
      extensions.empty? ? capabilities : capabilities.merge(extensions:)
    end

    def transport
      settings = self.class
      if settings.transport
        resolve(settings.transport)
      elsif settings.url
        HTTP.new(resolve(settings.url), headers: method(:request_headers), timeout: settings.timeout,
                                        unauthorized: method(:unauthorized), responded: method(:responded), config:)
      elsif settings.command
        Stdio.new(settings.command.map { |part| resolve(part) },
                  env: settings.env.transform_values { |value| resolve(value) },
                  directory: resolve(settings.directory), timeout: settings.timeout, config:)
      else
        raise ConfigurationError, "#{settings.name || 'MCP'} needs a url, a command, or a transport"
      end
    end

    def request_headers(verb)
      headers = self.class.headers.transform_values { |value| resolve(value) }
      return headers.merge(oauth.authorization_headers(verb)) if self.class.oauth_settings

      token = resolve(self.class.bearer_token)
      token ? headers.merge('Authorization' => "Bearer #{token}") : headers
    end

    def oauth
      settings = self.class.oauth_settings or raise ConfigurationError, "#{name} does not use OAuth"
      owner = resolve(settings[:owner])
      raise ArgumentError, "#{name} needs an owner for OAuth credentials" if settings[:owner] && owner.nil?

      @oauth ||= OAuth.new(resolve(self.class.url), owner:, resolve: method(:resolve), config:,
                                                    **settings.except(:owner))
    end

    def config
      @context&.config || RubyLLM.config
    end

    def unauthorized(headers, status, recovered)
      @challenge = OAuth.challenge(headers['www-authenticate'] || headers['WWW-Authenticate'])
      return unless status == 401 && self.class.oauth_settings

      oauth.recover(@challenge, nonce: dpop_nonce(headers), recovered:)
    end

    def responded(headers)
      oauth.remember_nonce(dpop_nonce(headers)) if self.class.oauth_settings
    end

    def dpop_nonce(headers)
      headers['dpop-nonce'] || headers['DPoP-Nonce']
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
