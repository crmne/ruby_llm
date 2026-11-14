# frozen_string_literal: true

module RubyLLM
  class Provider
    # The class-level DSL a Provider subclass declares its protocols with,
    # and the registry Provider.register adds the class to. Provider
    # extends this module rather than including it, so these become class
    # methods on Provider and every subclass.
    module Registration
      attr_reader :default_protocol # :nodoc:

      # Registers the protocol named +protocol_class+ under +name+. Pass the
      # class by name to have it loaded on first use rather than now. The
      # first registered protocol becomes the provider's default. Pass
      # +batches:+ a module, or its name, to compose batch operations into
      # the protocol.
      #
      #   protocol :chat_completions, 'RubyLLM::Protocols::ChatCompletions'
      #   protocol :responses, 'RubyLLM::Protocols::Responses',
      #            batches: 'RubyLLM::Protocols::Responses::Batches'
      #
      def protocol(name, protocol_class, batches: nil)
        @default_protocol = name.to_sym if protocol_definitions.empty?
        protocol_definitions[name.to_sym] = protocol_class
        batch_definitions[name.to_sym] = batches
        @protocols = nil
      end

      def protocols # :nodoc:
        @protocols ||= protocol_definitions.to_h { |name, definition| [name, build_protocol(name, definition)] }
      end

      def protocol_definitions # :nodoc:
        @protocol_definitions ||= {}
      end

      def batch_definitions # :nodoc:
        @batch_definitions ||= {}
      end

      # Returns the part of +message+ that holds its answer, as read by the
      # first of the provider's protocols that marks parts of a turn as
      # intermediate, or +nil+ when none does. Such a protocol defines
      # +parse_answer_text(message)+ as a class method.
      def answer_text(message) # :nodoc:
        protocols.each_value.lazy.filter_map do |protocol|
          protocol.parse_answer_text(message) if protocol.respond_to?(:parse_answer_text)
        end.first
      end

      # Returns the pages hosted web searches used for +message+, as read by
      # each of the provider's protocols that reports them. Such a protocol
      # defines +parse_web_sources(message)+ as a class method.
      def web_sources(message) # :nodoc:
        protocols.each_value.flat_map do |protocol|
          protocol.respond_to?(:parse_web_sources) ? protocol.parse_web_sources(message) : []
        end
      end

      # Registers +provider_class+ under the slug +name+, making it
      # available to RubyLLM.chat and the other top-level helpers. Pass the
      # class by name to have it loaded on first use rather than now; its
      # slug and Configuration accessors are stamped when it loads. A
      # provider gem may pass the path to its bundled model catalog.
      #
      #   RubyLLM::Provider.register :acme, 'RubyLLM::Providers::Acme'
      #   RubyLLM::Provider.register :acme, RubyLLM::Providers::Acme
      #   RubyLLM::Provider.register :acme, 'RubyLLM::Providers::Acme',
      #                              models: File.expand_path('../../../models.json', __dir__)
      #
      def register(name, provider_class, models: nil)
        name = name.to_sym
        registrations[name] = provider_class
        models ? model_registry_files[name] = models : model_registry_files.delete(name)

        if provider_class.is_a?(Module)
          resolved[name] = finish_registration(name, provider_class)
        else
          resolved.delete(name)
        end
      end

      # Removes the provider registered under +name+, with its bundled
      # catalog. The provider's configuration options stay declared.
      #
      #   RubyLLM::Provider.unregister :acme
      #
      def unregister(name)
        name = name.to_sym
        resolved.delete(name)
        model_registry_files.delete(name)
        registrations.delete(name)
      end

      def registrations # :nodoc:
        @registrations ||= {}
      end

      # The slug of the registered provider that +option+ belongs to, or
      # +nil+. The longest matching slug wins, so ollama_cloud_api_base
      # belongs to ollama_cloud rather than ollama.
      def slug_for_option(option) # :nodoc:
        name = option.to_s
        registrations.keys.select { |slug| name.start_with?("#{slug}_") }.max_by(&:length)
      end

      def resolve(name) # :nodoc:
        name = name.to_sym
        return resolved[name] if resolved.key?(name)

        registration = registrations[name]
        return unless registration

        resolved[name] = finish_registration(name, registration)
      end

      def resolve!(name) # :nodoc:
        resolve(name) ||
          raise(Error, "Unknown provider: #{name.inspect}. Available providers: #{registrations.keys.join(', ')}")
      end

      # Returns the global registry of providers, a hash mapping slug
      # symbols to provider classes. Resolving it loads every registered
      # provider; ::resolve loads one.
      def providers
        resolve_all
        resolved
      end

      # Loads every registered provider. Repeated calls are cheap: only a
      # registration added since the last one is resolved.
      def resolve_all # :nodoc:
        return if resolved.size == registrations.size

        registrations.each_key { |slug| resolve(slug) }
      end

      def resolved # :nodoc:
        @resolved ||= {}
      end

      def model_registry_files # :nodoc:
        @model_registry_files ||= {}
      end

      def configured_providers(config) # :nodoc:
        providers.select do |_slug, provider_class|
          provider_class.configured?(config)
        end.values
      end

      def configured_remote_providers(config) # :nodoc:
        providers.select do |_slug, provider_class|
          provider_class.remote? && provider_class.configured?(config)
        end.values
      end

      private

      def finish_registration(slug, registration)
        provider_class = registration.is_a?(Module) ? registration : load_provider_class(slug, registration)
        provider_class.slug = slug.to_s
        RubyLLM::Configuration.register_provider_options(
          provider_class.configuration_options + [:"#{slug}_protocol"]
        )
        provider_class
      end

      def load_provider_class(slug, class_name)
        Object.const_get(class_name)
      rescue NameError => e
        raise ConfigurationError, "Provider #{slug.inspect} is registered as #{class_name.inspect}, " \
                                  "which could not be loaded: #{e.message}"
      end

      def build_protocol(name, definition)
        protocol_class = definition.is_a?(Module) ? definition : Object.const_get(definition)
        batches = batch_definitions[name]
        batches = Object.const_get(batches) unless batches.nil? || batches.is_a?(Module)
        batches ? Class.new(protocol_class) { include batches } : protocol_class
      end
    end
  end
end
