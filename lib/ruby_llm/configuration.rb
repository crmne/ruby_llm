# frozen_string_literal: true

module RubyLLM
  # Global configuration for RubyLLM
  class Configuration
    class << self
      # Declare a single configuration option.
      def option(key, default = nil)
        key = key.to_sym
        return if options.include?(key)

        send(:attr_accessor, key)
        option_keys << key
        defaults[key] = default
      end

      def register_provider_options(options)
        Array(options).each { |key| option(key, nil) }
      end

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
    option :default_model, 'gpt-5.4'
    option :default_embedding_model, 'text-embedding-3-small'
    option :default_moderation_model, 'omni-moderation-latest'
    option :default_image_model, 'gpt-image-1.5'
    option :default_transcription_model, 'whisper-1'

    option :model_registry_file, -> { File.expand_path('models.json', __dir__) }
    option :model_registry_class, 'Model'

    option :use_new_acts_as, false

    option :request_timeout, 300
    option :max_retries, 3
    option :retry_interval, 0.1
    option :retry_backoff_factor, 2
    option :retry_interval_randomness, 0.5
    option :http_proxy, nil

    option :logger, nil
    option :log_file, -> { $stdout }
    option :log_level, -> { ENV['RUBYLLM_DEBUG'] ? Logger::DEBUG : Logger::INFO }
    option :log_stream_debug, -> { ENV['RUBYLLM_STREAM_DEBUG'] == 'true' }
    option :log_regexp_timeout, -> { Regexp.respond_to?(:timeout) ? (Regexp.timeout || 1.0) : nil }

    def initialize
      self.class.send(:defaults).each do |key, default|
        value = default.respond_to?(:call) ? instance_exec(&default) : default
        public_send("#{key}=", value)
      end
    end

    def instance_variables
      super.reject { |ivar| ivar.to_s.match?(/_id|_key|_secret|_token$/) }
    end

    def log_regexp_timeout=(value)
      if value.nil?
        @log_regexp_timeout = nil
      elsif Regexp.respond_to?(:timeout)
        @log_regexp_timeout = value
      else
        RubyLLM.logger.warn("log_regexp_timeout is not supported on Ruby #{RUBY_VERSION}")
        @log_regexp_timeout = value
      end
    end
  end
end
