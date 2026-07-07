# frozen_string_literal: true

require 'logger'

module RubyLLM
  # A Configuration holds every RubyLLM setting: provider credentials,
  # default models, timeouts, retries, logging, and the model registry.
  # The global instance is yielded by RubyLLM.configure and available as
  # RubyLLM.config.
  #
  #   RubyLLM.configure do |config|
  #     config.openai_api_key = ENV['OPENAI_API_KEY']
  #     config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  #   end
  #
  # RubyLLM.context yields an isolated copy for per-request or per-tenant
  # overrides.
  #
  # Provider credentials such as +openai_api_key+ are declared by each
  # provider. See the configuration guides for the full list.
  #
  # Assigning an empty or whitespace-only string to any option stores
  # +nil+, so unset environment variables behave as if the option was
  # never set.
  class Configuration
    class << self
      def option(key, default = nil) # :nodoc:
        key = key.to_sym
        return if options.include?(key)

        attr_reader key

        define_method("#{key}=") do |value|
          value = nil if value.is_a?(String) && value.strip.empty?
          instance_variable_set(:"@#{key}", value)
        end

        option_keys << key
        defaults[key] = default
      end

      def register_provider_options(options) # :nodoc:
        Array(options).each { |key| option(key, nil) }
      end

      # Returns the names of all declared options as an array of symbols,
      # including options registered by providers.
      def options
        option_keys.dup
      end

      private

      def option_keys = @option_keys ||= []
      def defaults = @defaults ||= {}
      private :option
    end

    # System-level options are declared here.
    # Provider-specific options are declared in each provider class via
    # `self.configuration_options` and registered through Provider.register.

    ##
    # :attr_accessor: default_model
    #
    # The model id used by RubyLLM.chat when no model is given.
    # Default: <tt>'gpt-5.4'</tt>.
    option :default_model, 'gpt-5.4'

    ##
    # :attr_accessor: default_embedding_model
    #
    # The model id used by RubyLLM.embed when no model is given.
    # Default: <tt>'text-embedding-3-small'</tt>.
    option :default_embedding_model, 'text-embedding-3-small'

    ##
    # :attr_accessor: default_moderation_model
    #
    # The model id used by RubyLLM.moderate when no model is given.
    # Default: <tt>'omni-moderation-latest'</tt>.
    option :default_moderation_model, 'omni-moderation-latest'

    ##
    # :attr_accessor: default_image_model
    #
    # The model id used by RubyLLM.paint when no model is given.
    # Default: <tt>'gpt-image-1.5'</tt>.
    option :default_image_model, 'gpt-image-1.5'

    ##
    # :attr_accessor: default_speech_model
    #
    # The model id used by RubyLLM.speak when no model is given.
    # Default: <tt>'gpt-4o-mini-tts'</tt>.
    option :default_speech_model, 'gpt-4o-mini-tts'

    ##
    # :attr_accessor: default_transcription_model
    #
    # The model id used by RubyLLM.transcribe when no model is given.
    # Default: <tt>'whisper-1'</tt>.
    option :default_transcription_model, 'whisper-1'

    ##
    # :attr_accessor: model_registry_file
    #
    # Path of the JSON file holding the model registry. Defaults to the
    # copy bundled with the gem. Point it at a writable location when the
    # gem directory is read-only.
    option :model_registry_file, -> { File.expand_path('models.json', __dir__) }

    ##
    # :attr_accessor: model_registry_class
    #
    # Name of the ActiveRecord class backing the registry in Rails apps,
    # as a string. Default: <tt>'Model'</tt>.
    option :model_registry_class, 'Model'

    ##
    # :attr_accessor: model_registry_source
    #
    # Source object the model registry loads models from. Rails apps
    # using the acts_as helpers set this automatically. Default: +nil+.
    option :model_registry_source, nil

    ##
    # :attr_accessor: request_timeout
    #
    # Seconds to wait for a response before timing out. Default: 300.
    option :request_timeout, 300

    ##
    # :attr_accessor: max_retries
    #
    # Number of times to retry failed requests. Default: 3.
    option :max_retries, 3

    ##
    # :attr_accessor: retry_interval
    #
    # Initial delay in seconds before the first retry. Default: 0.1.
    option :retry_interval, 0.1

    ##
    # :attr_accessor: retry_backoff_factor
    #
    # Multiplier applied to the retry delay after each attempt.
    # Default: 2.
    option :retry_backoff_factor, 2

    ##
    # :attr_accessor: retry_interval_randomness
    #
    # Random jitter factor applied to retry delays. Default: 0.5.
    option :retry_interval_randomness, 0.5

    ##
    # :attr_accessor: http_proxy
    #
    # Proxy URL for all requests, such as
    # <tt>'http://proxy.example.com:8080'</tt>. HTTP, authenticated, and
    # SOCKS5 proxies are supported. Default: +nil+.
    option :http_proxy, nil

    ##
    # :attr_accessor: tool_concurrency
    #
    # How chats run multiple tool calls from one response: +false+ for
    # sequential execution, +true+ or +:threads+ for threads, +:fibers+
    # for fibers via the async gem. Default: +false+.
    option :tool_concurrency, false

    ##
    # :attr_accessor: auto_upload_large_files
    #
    # Whether oversized local attachments are uploaded to provider file
    # storage automatically. Default: +true+.
    option :auto_upload_large_files, true

    ##
    # :attr_accessor: logger
    #
    # Logger receiving RubyLLM output. When set, it overrides #log_file
    # and #log_level. Default: +nil+.
    option :logger, nil

    ##
    # :attr_accessor: instrumenter
    #
    # Object receiving instrumentation events. It must respond to
    # <tt>instrument(name, payload)</tt> and accept an optional block,
    # like ActiveSupport::Notifications, which Rails apps use
    # automatically. Default: +nil+.
    option :instrumenter, nil

    ##
    # :attr_accessor: deprecation_behavior
    #
    # How deprecation warnings are handled: +:warn+, +:silence+, or
    # +:raise+. Default: +:warn+.
    option :deprecation_behavior, :warn

    ##
    # :attr_accessor: faraday_adapter
    #
    # Faraday adapter used for HTTP requests. Default: +:net_http+.
    option :faraday_adapter, :net_http

    ##
    # :attr_accessor: log_file
    #
    # Destination for the built-in logger, a path or an IO.
    # Default: <tt>$stdout</tt>.
    option :log_file, -> { $stdout }

    ##
    # :attr_accessor: log_level
    #
    # Severity of the built-in logger. Defaults to <tt>Logger::DEBUG</tt>
    # when the +RUBYLLM_DEBUG+ environment variable is set,
    # <tt>Logger::INFO</tt> otherwise.
    option :log_level, -> { ENV['RUBYLLM_DEBUG'] ? Logger::DEBUG : Logger::INFO }

    ##
    # :attr_accessor: log_stream_debug
    #
    # Whether raw streaming chunks are logged. Defaults to +true+ when
    # the +RUBYLLM_STREAM_DEBUG+ environment variable is <tt>'true'</tt>,
    # +false+ otherwise.
    option :log_stream_debug, -> { ENV['RUBYLLM_STREAM_DEBUG'] == 'true' }

    ##
    # :attr_accessor: log_regexp_timeout
    #
    # Timeout in seconds for the regular expressions that scrub logged
    # payloads. Defaults to the global <tt>Regexp.timeout</tt>, or 1.0
    # when none is set. Requires Ruby 3.2 or later; on older Rubies
    # setting a value logs a warning.
    option :log_regexp_timeout, -> { Regexp.respond_to?(:timeout) ? (Regexp.timeout || 1.0) : nil }

    def initialize # :nodoc:
      self.class.send(:defaults).each do |key, default|
        value = default.respond_to?(:call) ? instance_exec(&default) : default
        public_send("#{key}=", value)
      end
    end

    def instance_variables # :nodoc:
      super.reject { |ivar| ivar.to_s.match?(/(_id|_key|_secret|_token|_credential_provider)$/) }
    end

    remove_method :log_regexp_timeout=
    def log_regexp_timeout=(value) # :nodoc:
      if value && !Regexp.respond_to?(:timeout)
        RubyLLM.logger.warn("log_regexp_timeout is not supported on Ruby #{RUBY_VERSION}")
      end
      @log_regexp_timeout = value
    end
  end
end
