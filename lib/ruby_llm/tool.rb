# frozen_string_literal: true

module RubyLLM
  # Parameter definition for Tool methods. Specifies type constraints,
  # descriptions, and whether parameters are required.
  class Parameter
    attr_reader :name, :type, :description, :required

    def initialize(name, type: 'string', desc: nil, required: true)
      @name = name
      @type = type
      @description = desc
      @required = required
    end
  end

  # Base class for creating tools that AI models can use. Provides a simple
  # interface for defining parameters and implementing tool behavior.
  #
  # Example:
  #    require 'tzinfo'
  #
  #    class TimeInfo < RubyLLM::Tool
  #      description 'Gets the current time in various timezones'
  #      param :timezone, desc: "Timezone name (e.g., 'UTC', 'America/New_York')"
  #
  #      def execute(timezone:)
  #        time = TZInfo::Timezone.get(timezone).now.strftime('%Y-%m-%d %H:%M:%S')
  #        "Current time in #{timezone}: #{time}"
  #       rescue StandardError => e
  #          { error: e.message }
  #       end
  #    end
  class Tool
    class << self
      def description(text = nil)
        return @description unless text

        @description = text
      end

      def param(name, **options)
        parameters[name] = Parameter.new(name, **options)
      end

      def parameters
        @parameters ||= {}
      end

      def cacheable?
        false
      end

      def cache_expiration(expires_in = 12.hours)
        @cache_expiration = expires_in
      end
    end

    def name
      self.class.name
          .unicode_normalize(:nfkd)
          .encode('ASCII', replace: '')
          .gsub(/[^a-zA-Z0-9_-]/, '-')
          .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
          .gsub(/([a-z\d])([A-Z])/, '\1_\2')
          .downcase
          .delete_suffix('_tool')
    end

    def description
      self.class.description
    end

    def parameters
      self.class.parameters
    end

    def call(args)
      RubyLLM.logger.debug "Tool #{name} called with: #{args.inspect}"
      if RubyLLM.config.perform_caching && self.class.cacheable?
        cache_key = [name, args].to_param
        RubyLLM.logger.debug "Retrieving result from cache with key: #{cache_key.inspect}"

        result = RubyLLM.cache.fetch(cache_key, expires_in: self.class.cache_expiration) do
          execute(**args.transform_keys(&:to_sym))
        end
      else
        execute(**args.transform_keys(&:to_sym))
      end
      RubyLLM.logger.debug "Tool #{name} returned: #{result.inspect}"
    end

    def execute(...)
      raise NotImplementedError, 'Subclasses must implement #execute'
    end
  end
end
