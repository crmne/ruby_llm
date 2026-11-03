# frozen_string_literal: true

require 'date'
require 'yaml'

# Fills the prices models.dev cannot express yet, per character, second of
# audio, or search unit, from tasks/data/model_unit_prices.yml. A model
# models.dev prices keeps its models.dev pricing, and the entry is reported.
class ModelUnitPrices
  FILE = File.expand_path('../data/model_unit_prices.yml', __dir__)
  UNITS = %w[characters audio_seconds search_units].freeze

  Entry = Data.define(:provider, :model, :unit, :per_million, :quoted, :source, :checked) do
    def key
      "#{provider}:#{model}"
    end
  end

  attr_reader :entries, :notices

  def self.load(file = FILE)
    rows = YAML.safe_load_file(file, permitted_classes: [Date])
    new(rows.map { |row| Entry.new(**row.transform_keys(&:to_sym)) })
  end

  def initialize(entries)
    @entries = entries
    @notices = []
  end

  def apply(models)
    by_key = entries.group_by(&:key)
    priced = models.map do |model|
      price(model, by_key.delete("#{model.provider}:#{model.id}") || [])
    end
    by_key.each_value { |missing| missing.each { |entry| notices << missing_notice(entry) } }
    priced
  end

  private

  def price(model, model_entries)
    cost = models_dev_cost(model)
    pricing = model.pricing.to_h
    stale = stale_units(pricing, cost)
    return model if stale.empty? && model_entries.empty?

    pricing = pricing.except(*stale)
    model_entries.each do |entry|
      if cost.empty?
        pricing[entry.unit.to_sym] = { standard: { input_per_million: entry.per_million } }
      else
        notices << models_dev_notice(entry)
      end
    end

    RubyLLM::Model.new(model.to_h.merge(pricing:))
  end

  def stale_units(pricing, cost)
    UNITS.map(&:to_sym).select { |unit| pricing.key?(unit) && cost[unit].nil? }
  end

  def models_dev_cost(model)
    cost = model.metadata[:cost] || model.metadata['cost'] || {}
    cost.transform_keys(&:to_sym).compact
  end

  def models_dev_notice(entry)
    "#{entry.key} has a models.dev price, so its #{entry.unit} price was not applied. " \
      "#{entry.source} listed #{entry.quoted} on #{entry.checked}: remove the entry, " \
      'and report the price to models.dev if it differs.'
  end

  def missing_notice(entry)
    "#{entry.key} is not in the registry, so its #{entry.unit} price was not applied."
  end
end
