# frozen_string_literal: true

module MutationTesting
  # Chooses the specs for a change-scoped run. Mutineer captures coverage for
  # every spec it is given before it runs a mutant, so a run over the whole
  # suite costs minutes even for a one-line change. The coverage maps earlier
  # runs left in tmp/mutineer name the specs that reach each source; a run
  # takes those, the source's own spec, and every spec changed since the base.
  # Without a map for a source, the run takes the pass's whole suite.
  class SpecSelection
    def initialize(root, base: nil)
      @root = root
      @base = base
    end

    def for(pass, sources)
      suite = pass.specs(@root)
      covering = sources.map { |source| covering_specs(source) }
      return suite if covering.any?(&:nil?)

      chosen = suite & (covering.flatten + sources.filter_map { |source| own_spec(source) } + changed_specs)
      chosen.empty? ? suite : chosen
    end

    private

    def covering_specs(source)
      prefix = "#{source}:"
      found = coverage_maps.filter_map do |map|
        lines = map.select { |key, _| key.start_with?(prefix) }
        lines.values.flatten if lines.any?
      end
      found.flatten.uniq unless found.empty?
    end

    def coverage_maps
      @coverage_maps ||= Dir.glob(File.join(MutationTesting.state_dir(@root), 'cache', '*',
                                            'coverage.json')).filter_map do |path|
        JSON.parse(File.read(path))['map']
      rescue JSON::ParserError
        nil
      end
    end

    def own_spec(source)
      spec = source.sub(%r{\Alib/}, 'spec/').sub(/\.rb\z/, '_spec.rb')
      spec if File.file?(File.join(@root, spec))
    end

    def changed_specs
      return [] unless @base

      listed = MutationTesting.git(@root, 'diff', '--name-only', @base, '--', 'spec')
      untracked = MutationTesting.git(@root, 'ls-files', '--others', '--exclude-standard', 'spec')
      [listed, untracked].compact.flat_map { |output| output.lines(chomp: true) }
    end
  end
end
