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
    end

    def name
      klass_name = self.class.name
      normalized = klass_name.to_s.dup.force_encoding('UTF-8').unicode_normalize(:nfkd)
      normalized.encode('ASCII', replace: '')
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
      result = execute(**args.transform_keys(&:to_sym))
      RubyLLM.logger.debug "Tool #{name} returned: #{result.inspect}"
      result
    end

    def execute(...)
      raise NotImplementedError, 'Subclasses must implement #execute'
    end
  end
end
