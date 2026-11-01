# frozen_string_literal: true

module MutationTesting
  # Combines shard reports into one report in mutineer's JSON format, usable
  # as a --baseline, and renders it with mutineer's HTML report.
  module Report
    LISTS = %w[survivors no_coverage uncapturable unplaceable ran_at_load no_verdict ignored per_source].freeze

    module_function

    def combine(documents)
      summary = sum(documents.map { |document| document.fetch('summary') })
      legacy = sum(documents.filter_map { |document| document.dig('summary', 'legacy_id_matches') })
      summary.merge!('score' => score(summary['killed'], summary['survived']), 'scoped' => false, 'id_format' => 2,
                     'legacy_id_matches' => { 'ignore' => legacy['ignore'], 'baseline' => legacy['baseline'] })
      lists = LISTS.to_h do |key|
        [key, documents.flat_map { |document| document.fetch(key, []) }.sort_by { |entry| sort_key(entry) }]
      end
      { 'schema_version' => documents.dig(0, 'schema_version') || '1.7', 'summary' => summary, **lists }
    end

    def sum(hashes)
      hashes.each_with_object(Hash.new(0)) do |hash, total|
        hash.each { |key, value| total[key] += value if value.is_a?(Integer) }
      end
    end

    def score(killed, survived)
      covered = killed + survived
      (killed.to_f / covered * 100).round(1) unless covered.zero?
    end

    def survivors_by_file(document)
      document.fetch('survivors').group_by { |survivor| survivor['file'] }.sort_by { |file, list| [-list.size, file] }
    end

    def html(document)
      require 'mutineer'
      html = StringIO.new
      reporter.new(Totals.new(document), {}).report(out: html, format: 'html')
      html.string
    end

    def reporter
      @reporter ||= Class.new(Mutineer::Reporter) do
        private

        def survivor_json(survivor) = survivor.transform_keys(&:to_sym)

        def per_source_json(_file, entry) = entry.transform_keys(&:to_sym)

        def ignored_json(ignored) = ignored.entry.transform_keys(&:to_sym)
      end
    end

    def sort_key(entry)
      [entry['file'].to_s, entry['line'].to_i, entry['operator'].to_s, entry['id'].to_s]
    end
  end

  # The aggregate interface Mutineer::Reporter reads, backed by a JSON report.
  class Totals
    COUNTS = {
      total: 'total', killed_count: 'killed', survived_count: 'survived', no_coverage_count: 'no_coverage',
      uncapturable_count: 'uncapturable', unplaceable_count: 'unplaceable', ran_at_load_count: 'ran_at_load',
      ignored_count: 'ignored', skipped_invalid_count: 'skipped_invalid', errored_count: 'errored',
      timeout_count: 'timeout'
    }.freeze

    def initialize(document)
      @document = document
    end

    COUNTS.each { |method, key| define_method(method) { @document.fetch('summary').fetch(key, 0) } }

    def unrun_count = unplaceable_count + skipped_invalid_count

    def mutation_score = @document.dig('summary', 'score')

    def surviving_mutants = @document.fetch('survivors')

    def by_source = @document.fetch('per_source').map { |entry| [entry['file'], entry] }

    def results = @document.fetch('ignored', []).map { |entry| Ignored.new(entry) }

    Ignored = Data.define(:entry) do
      def ignored? = true
    end
  end
end
