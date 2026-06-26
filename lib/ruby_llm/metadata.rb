# frozen_string_literal: true

module RubyLLM
  # Caller-supplied attribution for observability (not provider request params).
  # Distinct from RubyLLM::Context, which scopes configuration.
  Metadata = Data.define(:namespace, :tags) do
    def initialize(namespace: nil, tags: {})
      super(namespace: namespace, tags: tags.transform_keys(&:to_sym).freeze)
    end

    def merge(namespace: nil, tags: {})
      self.class.new(
        namespace: namespace.nil? ? self.namespace : namespace,
        tags: self.tags.merge(tags.transform_keys(&:to_sym))
      )
    end

    def self.coerce(metadata)
      return metadata if metadata.nil? || metadata.is_a?(self)

      attrs = metadata.transform_keys(&:to_sym)
      new(namespace: attrs[:namespace], tags: attrs[:tags] || {})
    end
  end
end
