# frozen_string_literal: true

require 'ruby_llm/schema'

module RubyLLM
  class Parameter # :nodoc:
    attr_reader :name, :type, :description, :required

    def initialize(name, type: 'string', description: nil, required: true)
      @name = name
      @type = type
      @description = description
      @required = required
    end
  end

  # A Tool is an action an AI model can call during a chat. Subclasses
  # describe themselves with ::description, declare their arguments, and
  # implement #execute:
  #
  #   class Weather < RubyLLM::Tool
  #     description "Gets current weather for a location"
  #
  #     def execute(latitude:, longitude:)
  #       response = Faraday.get "https://api.open-meteo.com/v1/forecast",
  #                              latitude: latitude, longitude: longitude,
  #                              current: "temperature_2m,wind_speed_10m"
  #       JSON.parse(response.body)
  #     end
  #   end
  #
  #   chat.with_tools(Weather).ask "What's the weather in Berlin?"
  #
  # When no parameters are declared, the argument schema is inferred from
  # #execute's keyword arguments: required keywords become required string
  # parameters and optional keywords become optional ones. Use ::parameter
  # or ::parameters when arguments need explicit types, descriptions, or
  # structure.
  class Tool
    POSITIONAL_PARAMETER_KINDS = %i[req opt rest].freeze # :nodoc:

    class << self
      attr_reader :parameters_schema_definition # :nodoc:

      # :call-seq:
      #   description(text) -> text
      #   description -> string or nil
      #
      # Sets the description the model sees for this tool, or returns the
      # current description when called without an argument.
      #
      #   class Weather < RubyLLM::Tool
      #     description "Gets current weather for a location"
      #   end
      #
      def description(text = nil)
        return @description unless text

        @description = text
      end

      # Declares a parameter for the tool. +options+ accepts +type:+
      # (defaults to <tt>'string'</tt>), +description:+, and +required:+
      # (defaults to +true+).
      #
      #   class Distance < RubyLLM::Tool
      #     description "Calculates distance between two cities"
      #     parameter :origin, description: "Origin city name"
      #     parameter :destination, description: "Destination city name"
      #     parameter :units, type: :string, description: "metric or imperial", required: false
      #   end
      #
      def parameter(name, **options)
        declared_parameters[name] = Parameter.new(name, **options)
      end

      def declared_parameters # :nodoc:
        @declared_parameters ||= {}
      end

      # Sets the JSON Schema for the tool's arguments. Accepts a schema hash,
      # a RubyLLM::Schema class or instance, or a block written in the
      # ruby_llm-schema DSL. Returns +self+.
      #
      #   class Scheduler < RubyLLM::Tool
      #     description "Books a meeting"
      #
      #     parameters do
      #       object :window, description: "Time window to reserve" do
      #         string :start, description: "ISO8601 start time"
      #         string :finish, description: "ISO8601 end time"
      #       end
      #       array :participants, of: :string
      #     end
      #   end
      #
      # Raises ArgumentError when called without a schema or a block.
      def parameters(schema = nil, &block)
        if schema.nil? && block.nil?
          raise ArgumentError, 'parameters requires a schema or a block; declare single arguments with parameter'
        end

        @parameters_schema_definition = SchemaDefinition.new(schema:, block:)
        self
      end

      # :call-seq:
      #   provider_options(options) -> self
      #   provider_options -> hash
      #
      # Sets provider-specific metadata, such as Anthropic's +cache_control+
      # hints, merged verbatim into the tool payload sent to the provider.
      # Without an argument, returns the current options.
      #
      #   provider_options cache_control: { type: "ephemeral" }
      #
      # Raises ArgumentError if +options+ is +nil+.
      def provider_options(options = (get = true))
        return @provider_options ||= {} if get
        raise ArgumentError, 'provider_options does not accept nil' if options.nil?

        @provider_options = options.to_h
        self
      end

      def split_result(result) # :nodoc:
        case result
        when Attachment then ['', [result]]
        when Array then split_array_result(result)
        else [result_content(result), []]
        end
      end

      private

      def split_array_result(result)
        parts = result.flatten.compact
        return [result_content(result), []] if parts.none?(Attachment)

        texts, attachments = parts.partition { |part| part.is_a?(String) }
        unless attachments.all?(Attachment)
          raise ArgumentError, 'Tool results mixing attachments can only contain Strings and RubyLLM::Attachments'
        end

        [texts.join("\n\n"), attachments]
      end

      def result_content(result)
        case result
        when String then result
        when Hash, Array, SearchResults then result.to_json
        else result.to_s
        end
      end
    end

    # Returns the name the model calls this tool by, derived from the class
    # name: underscored, reduced to ASCII, with a trailing "_tool" removed.
    # Override this method to choose a different name.
    #
    #   WeatherLookup.new.name  # => "weather_lookup"
    #
    def name
      klass_name = self.class.name
      normalized = klass_name.to_s.dup.force_encoding('UTF-8').unicode_normalize(:nfkd)
      ascii_name = normalized.encode('ASCII', replace: '').gsub(/[^a-zA-Z0-9_-]/, '-')
      Utils.underscore(ascii_name).delete_suffix('_tool')
    end

    # Returns the tool description declared on the class with ::description.
    def description
      self.class.description
    end

    def declared_parameters # :nodoc:
      self.class.declared_parameters
    end

    def provider_options # :nodoc:
      self.class.provider_options
    end

    def parameters_schema # :nodoc:
      return @parameters_schema if defined?(@parameters_schema)

      @parameters_schema = begin
        definition = self.class.parameters_schema_definition
        if definition&.present?
          definition.json_schema
        elsif declared_parameters.any?
          SchemaDefinition.from_parameters(declared_parameters)&.json_schema
        else
          SchemaDefinition.from_parameters(inferred_parameters, allow_empty: true)&.json_schema
        end
      end
    end

    def call(args) # :nodoc:
      normalized_args = normalize_args(args)
      validation_error = validate_keyword_arguments(normalized_args)
      return { error: "Invalid tool arguments: #{validation_error}" } if validation_error

      RubyLLM.logger.debug { "Tool #{name} called with: #{normalized_args.inspect}" }
      result = execute(**normalized_args)
      RubyLLM.logger.debug { "Tool #{name} returned: #{result.inspect}" }
      result
    end

    # Runs the tool with the arguments chosen by the model. Subclasses must
    # implement this method; the base implementation raises
    # NotImplementedError. The return value is sent back to the model.
    # Return a Hash like <tt>{ error: "..." }</tt> to report a recoverable
    # failure.
    def execute(...)
      raise NotImplementedError, 'Subclasses must implement #execute'
    end

    protected

    def normalize_args(args) # :nodoc:
      return {} if args.nil?
      return args.transform_keys(&:to_sym) if args.respond_to?(:transform_keys)

      {}
    end

    def validate_keyword_arguments(arguments) # :nodoc:
      required_keywords, optional_keywords, accepts_extra_keywords, accepts_positional_arguments =
        execute_keyword_signature

      return nil if required_keywords.empty? && optional_keywords.empty? && accepts_positional_arguments

      argument_keys = arguments.keys
      missing_keyword = (required_keywords - argument_keys).first
      return "missing keyword: #{missing_keyword}" if missing_keyword
      return nil if accepts_extra_keywords

      unknown_keyword = (argument_keys - (required_keywords + optional_keywords)).first
      return "unknown keyword: #{unknown_keyword}" if unknown_keyword

      nil
    end

    def execute_keyword_signature # :nodoc:
      keyword_signature = method(:execute).parameters
      required_keywords = keyword_signature.filter_map { |kind, name| name if kind == :keyreq }
      optional_keywords = keyword_signature.filter_map { |kind, name| name if kind == :key }
      accepts_extra_keywords = keyword_signature.any? { |kind, _| kind == :keyrest }
      accepts_positional_arguments = keyword_signature.any? do |kind, _|
        POSITIONAL_PARAMETER_KINDS.include?(kind)
      end

      [required_keywords, optional_keywords, accepts_extra_keywords, accepts_positional_arguments]
    end

    def inferred_parameters # :nodoc:
      required_keywords, optional_keywords, = execute_keyword_signature

      (required_keywords + optional_keywords).to_h do |name|
        [name, Parameter.new(name, required: required_keywords.include?(name))]
      end
    end

    class SchemaDefinition # :nodoc:
      def self.from_parameters(parameters, allow_empty: false)
        return nil if parameters.nil? || (parameters.empty? && !allow_empty)

        properties = parameters.to_h do |name, param|
          schema = {
            type: map_type(param.type),
            description: param.description
          }.compact

          schema[:items] = default_items_schema if schema[:type] == 'array'

          [name.to_s, schema]
        end

        required = parameters.select { |_, param| param.required }.keys.map(&:to_s)

        json_schema = {
          type: 'object',
          properties: properties,
          required: required,
          additionalProperties: false,
          strict: true
        }

        new(schema: json_schema)
      end

      def self.map_type(type)
        case type.to_s
        when 'integer', 'int' then 'integer'
        when 'number', 'float', 'double' then 'number'
        when 'boolean' then 'boolean'
        when 'array' then 'array'
        when 'object' then 'object'
        else
          'string'
        end
      end

      def self.default_items_schema
        { type: 'string' }
      end

      def initialize(schema: nil, block: nil)
        @schema = schema
        @block = block
      end

      def present?
        @schema || @block
      end

      def json_schema
        @json_schema ||= RubyLLM::Utils.deep_stringify_keys(resolve_schema)
      end

      private

      def resolve_schema
        return resolve_direct_schema(@schema) if @schema
        return build_from_block(&@block) if @block

        nil
      end

      def resolve_direct_schema(schema)
        return extract_schema(schema.to_json_schema) if schema.respond_to?(:to_json_schema)
        return RubyLLM::Utils.deep_dup(schema) if schema.is_a?(Hash)
        if schema.is_a?(Class) && schema.method_defined?(:to_json_schema)
          return extract_schema(schema.new.to_json_schema)
        end

        nil
      end

      def build_from_block(&)
        schema_class = RubyLLM::Schema.create(&)
        extract_schema(schema_class.new.to_json_schema)
      end

      def extract_schema(schema_hash)
        return nil unless schema_hash.is_a?(Hash)

        schema = schema_hash[:schema] || schema_hash['schema'] || schema_hash
        RubyLLM::Utils.deep_dup(schema)
      end
    end
  end
end
