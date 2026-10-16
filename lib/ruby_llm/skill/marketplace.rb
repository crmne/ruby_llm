# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'pathname'
require 'securerandom'

module RubyLLM
  class Skill
    # A Marketplace is a set of skills copied into +vendor/skills+ from a
    # plugin marketplace: a GitHub repository or a directory whose
    # marketplace file lists plugins, in the format Claude Code, Codex, and
    # Cursor share. Each plugin's skill folders land in
    # <tt>vendor/skills/<marketplace>/<plugin>/</tt>, where Skill.find and
    # Chat#with_skills find them after the skills in +app/skills+.
    #
    # RubyLLM fetches a marketplace only in ::add and #update, never when a
    # chat runs. The skills are files in your project: review them and
    # commit them like any other code.
    #
    #   marketplace = RubyLLM::Skill::Marketplace.add("anthropics/skills")
    #   marketplace.name    # => "anthropic-agent-skills"
    #   marketplace.plugins # => ["claude-api", "document-skills", ...]
    #   marketplace.skills.map(&:name) # => ["claude-api", "docx", "pdf", ...]
    #
    #   RubyLLM.chat.with_skills(:pdf)
    class Marketplace
      include Support::Inspectable

      RECORD = 'marketplace.json' # :nodoc:

      # The marketplace's name, from its marketplace file.
      attr_reader :name

      # Where the marketplace came from: the argument ::add was given.
      attr_reader :source

      # The commit the skills were copied at, or +nil+ for a directory.
      attr_reader :commit

      # The marketplace's folder under +vendor/skills+, as a Pathname.
      attr_reader :path

      class << self
        # Returns the folder marketplaces are copied into: +vendor/skills+
        # under +Rails.root+, or under the current directory outside Rails.
        def root
          Skill.root.parent.parent.join('vendor/skills')
        end

        # Returns every marketplace under ::root, ordered by name.
        def all
          records.map { |record| new(record.dirname) }
        end

        # Returns the marketplace called +name+. Raises
        # MarketplaceNotFoundError when it was never added.
        #
        #   RubyLLM::Skill::Marketplace.find("anthropic-agent-skills")
        #
        def find(name)
          path = root.join(name.to_s)
          unless name.to_s.match?(Catalog::NAME) && path.join(RECORD).file?
            raise MarketplaceNotFoundError, "No marketplace named #{name} in #{root}"
          end

          new(path)
        end

        # Copies the skills of the marketplace at +source+ into ::root and
        # returns the Marketplace. +source+ is a GitHub repository, such as
        # <tt>"anthropics/skills"</tt>, with <tt>@</tt> and a branch, tag,
        # or commit to pin it, or the path of a directory. Adding a
        # marketplace again replaces its skills.
        #
        #   RubyLLM::Skill::Marketplace.add("acme/skills@v1.2.0")
        #   RubyLLM::Skill::Marketplace.add("../our-skills", only: "billing")
        #
        # Every plugin is added, apart from plugins without skills and
        # plugins whose source is not the marketplace or a GitHub
        # repository. +only+ names the plugins to add instead.
        #
        # Raises ArgumentError when +source+ is neither a directory nor a
        # repository, when +only+ names a plugin the marketplace lacks or
        # RubyLLM cannot fetch, and when another source was added under
        # the same name. Raises MarketplaceNotFoundError when GitHub has
        # no such repository, InvalidMarketplaceError when the marketplace
        # file or the archive is unusable or holds no skills, and
        # InvalidSkillError when a skill breaks the Agent Skills
        # specification. A failed add leaves the skills of an earlier one
        # in place.
        def add(source, only: nil)
          repository = Repository.new(source, local: true)
          repository.checkout do |directory, commit|
            catalog = Catalog.new(directory, repository.source)
            install(catalog, catalog.select(only), directory, source: repository.source, commit:, strict: !only.nil?)
          end
        end

        def roots # :nodoc:
          records.flat_map { |record| record.dirname.children.select(&:directory?).sort }
        end

        private

        def records
          root.glob("*/#{RECORD}").sort
        end

        def install(catalog, plugins, directory, source:, commit:, strict:)
          target = replaceable(root.join(catalog.name), source)
          scratch = root.join(".#{catalog.name}-#{SecureRandom.hex(4)}")
          plugins.each { |plugin| Plugin.new(plugin, directory).copy_to(scratch.join(plugin.name), strict:) }
          raise InvalidMarketplaceError, "#{source} has no skills to add" unless scratch.directory?

          scratch.join(RECORD).write("#{JSON.pretty_generate('source' => source, 'commit' => commit)}\n")
          target.rmtree if target.exist?
          scratch.rename(target)
          new(target)
        ensure
          scratch.rmtree if scratch&.exist?
        end

        def replaceable(target, source)
          return target unless target.exist?
          raise ArgumentError, "#{target} exists and is not a marketplace" unless target.join(RECORD).file?

          existing = new(target).source
          return target if existing.split('@').first == source.split('@').first

          raise ArgumentError, "A marketplace named #{target.basename} was added from #{existing}. Remove it first"
        end
      end

      def initialize(path) # :nodoc:
        @path = Pathname.new(path)
        @name = @path.basename.to_s
        record = JSON.parse(@path.join(RECORD).read)
        @source = record.fetch('source')
        @commit = record['commit']
      rescue JSON::ParserError, KeyError, TypeError
        raise InvalidMarketplaceError, "#{@path.join(RECORD)} is not a marketplace record"
      end

      # Returns the names of the plugins whose skills were added.
      def plugins
        plugin_folders.map { |folder| folder.basename.to_s }
      end

      # Returns the skills of every plugin, as Skill objects.
      def skills
        plugin_folders.flat_map { |folder| folder.children.select(&:directory?).sort.map { |skill| Skill.new(skill) } }
      end

      # Fetches the marketplace again and replaces the skills of the plugins
      # it has. Returns +self+. A marketplace pinned to a tag or a commit
      # fetches the same files. To add plugins the marketplace gained, call
      # ::add again. Raises as ::add does, including ArgumentError when the
      # marketplace no longer lists one of the plugins.
      def update
        fresh = self.class.add(source, only: plugins)
        @commit = fresh.commit
        self
      end

      # Deletes the marketplace's folder and its skills. Returns +self+.
      def remove
        path.rmtree
        self
      end

      def inspect_attributes # :nodoc:
        { name:, source:, commit: }
      end

      private

      def plugin_folders
        path.children.select(&:directory?).sort
      end
    end
  end
end
