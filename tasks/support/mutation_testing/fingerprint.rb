# frozen_string_literal: true

module MutationTesting
  # Digests what a shard's verdicts depend on: its sources, the whole spec tree
  # (specs, support files, cassettes, the dummy app), the mutineer settings,
  # and the tool versions. Files Git ignores, such as the dummy app's
  # databases and logs, are left out.
  class Fingerprint
    SETTINGS = %w[.mutineer.yml].freeze

    def initialize(root)
      @root = root
    end

    def shard(shard)
      digest = Digest::SHA256.new
      digest << [shard.name, shard.pass.name, *shard.pass.options, RUBY_VERSION,
                 MutationTesting.mutineer_version].join("\0")
      digest << spec_tree
      add_files(digest, shard.sources + SETTINGS)
      digest.hexdigest
    end

    def spec_tree
      @spec_tree ||= begin
        listed = MutationTesting.git(@root, 'ls-files', '--cached', '--others', '--exclude-standard', 'spec')
        files = listed ? listed.lines(chomp: true) : Dir.glob('spec/**/*', base: @root)
        add_files(Digest::SHA256.new, files.uniq.sort).hexdigest
      end
    end

    private

    def add_files(digest, paths)
      paths.each do |path|
        full = File.join(@root, path)
        next unless File.file?(full)

        digest << path << "\0" << File.size(full).to_s << "\0"
        digest.file(full)
      end
      digest
    end
  end
end
