# frozen_string_literal: true

module RubyLLM
  # Parameter definition for Tool methods. Specifies type constraints,
  # descriptions, and whether parameters are required.
  #
  # @!attribute name [r]
  #   @return [Symbol]
  # @!attribute required [r]
  #   @return [Boolean]
  # @!attribute schema [r]
  #   @return [RubyLLM::Schema]
  class Parameter
    attr_reader :name, :required, :schema

    # If providing schema directly MAKE SURE TO USE STRING KEYS.
    # Also note that under_scored keys are NOT automatically transformed to camelCase.
    # @param name [Symbol]
    # @param schema [Hash{String|Symbol => String|Array|Hash|Boolean|NilClass}, NilClass]
    def initialize(name, required: true, **schema)
      @name = name
      @required = required

      @schema = Schema.new(schema)
      @schema[:description] ||= @schema.delete(:desc) if @schema.key?(:desc)
      @schema[:type] ||= :string
    end

    # @return [String]
    def type
      @schema[:type]
    end

    # @return [String, NilClass]
    def description
      @schema[:description]
    end

    alias required? required
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

      # Define a parameter for the tool.
      # Examples:
      # ```ruby
      #   param :latitude, desc: "Latitude (e.g., 52.5200)" # Shorthand format
      #
      #   param :longitude, type: 'number', description: "Longitude (e.g., 13.4050)", required: false # Longer format
      #
      #   param :unit, type: :string, enum: %w[f c], description: "Temperature unit (e.g., celsius, fahrenheit)"
      #
      #   param :location, type: :object, desc: "Country and city where weather is requested.", properties: {
      #     country: { type: :string, description: "Full name of the country." },
      #     city: { type: :string, description: "Full name of the city." }
      #   }
      # ```
      # @param name [Symbol]
      # @param schema [Hash{String|Symbol => String|Numeric|Boolean|Hash|Array|NilClass}, NilClass]
      def param(name, required: true, **schema)
        parameters[name] = Parameter.new(name, required: required, **schema)
      end

      def parameters
        @parameters ||= {}
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
      result = execute(**args.transform_keys(&:to_sym))
      RubyLLM.logger.debug "Tool #{name} returned: #{result.inspect}"
      result
    end

    def execute(...)
      raise NotImplementedError, 'Subclasses must implement #execute'
    end
  end
end
