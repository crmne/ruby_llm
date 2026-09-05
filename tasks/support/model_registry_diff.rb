# frozen_string_literal: true

# Reports model removals and metadata losses during a registry refresh.
class ModelRegistryDiff
  GUARDED_FIELDS = %i[family created_at context_window max_output_tokens knowledge_cutoff].freeze

  class << self
    def call(existing_models, new_models)
      existing = index(existing_models)
      current = index(new_models)
      removed = (existing.keys - current.keys).sort.map { |key| "#{key} was removed" }

      removed + (existing.keys & current.keys).flat_map do |key|
        model_regressions(key, existing.fetch(key), current.fetch(key))
      end
    end

    private

    def index(models)
      models.to_h { |model| ["#{model.provider}:#{model.id}", model] }
    end

    def model_regressions(key, existing, current)
      regressions = lost_fields(key, existing, current)
      regressions.concat(lost_hash_values(key, 'modalities', existing.modalities.to_h, current.modalities.to_h))
      regressions.concat(lost_hash_values(key, 'pricing', existing.pricing.to_h, current.pricing.to_h))
      (existing.capabilities - current.capabilities).each do |capability|
        regressions << "#{key} lost capability #{capability}"
      end
      regressions << "#{key} changed type from #{existing.type} to #{current.type}" if existing.type != current.type
      regressions
    end

    def lost_fields(key, existing, current)
      GUARDED_FIELDS.filter_map do |field|
        old_value = existing.public_send(field)
        new_value = current.public_send(field)
        "#{key} lost #{field}" if !blank?(old_value) && blank?(new_value)
      end
    end

    def lost_hash_values(key, field, existing, current, path = [])
      existing.flat_map do |name, value|
        nested_path = path + [name]
        lost_value(key, field, nested_path, value, current[name])
      end
    end

    def lost_value(key, field, path, existing, current)
      return lost_hash_values(key, field, existing, current.is_a?(Hash) ? current : {}, path) if existing.is_a?(Hash)

      if existing.is_a?(Array)
        return (existing - Array(current)).map { |item| "#{key} lost #{field}.#{path.join('.')} value #{item}" }
      end

      return ["#{key} lost #{field}.#{path.join('.')}"] if !blank?(existing) && blank?(current)

      []
    end

    def blank?(value)
      return true if value.nil?
      return value.empty? if value.is_a?(String) || value.is_a?(Array)
      return value.empty? || value.values.all? { |nested| blank?(nested) } if value.is_a?(Hash)

      false
    end
  end
end
