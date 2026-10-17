# frozen_string_literal: true

require 'pathname'
require 'yaml'

module RubyLLM
  # A Skill is a folder of instructions, scripts, and reference files in the
  # open {Agent Skills}[https://agentskills.io/specification] format. Its
  # +SKILL.md+ starts with YAML front matter naming and describing the
  # skill, followed by the instructions in Markdown.
  #
  # Chat#with_skills gives skills to a chat. The model sees each skill's
  # name and description, and loads the instructions and files of the ones
  # a task needs.
  #
  #   skill = RubyLLM::Skill.find(:invoices)
  #   skill.name        # => "invoices"
  #   skill.description # => "Creates invoices as PDFs. Use when ..."
  #   skill.path        # => #<Pathname:/app/app/skills/invoices>
  class Skill
    include Support::Inspectable

    # The file every skill folder holds.
    FILE = 'SKILL.md'

    # Characters a name may have at most.
    MAX_NAME = 64

    # Characters a description may have at most.
    MAX_DESCRIPTION = 1024

    # Characters the compatibility field may have at most.
    MAX_COMPATIBILITY = 500

    FRONT_MATTER = /\A---[ \t]*\r?\n(.*?)^---[ \t]*(?:\r?\n|\z)/m
    NAME_FORMAT = /\A[[:alnum:]]+(?:-[[:alnum:]]+)*\z/
    private_constant :FRONT_MATTER, :NAME_FORMAT

    # The skill's name, matching its folder name.
    attr_reader :name

    # What the skill does and when to use it.
    attr_reader :description

    # The license the front matter names, or +nil+.
    attr_reader :license

    # The environment requirements the front matter states, or +nil+.
    attr_reader :compatibility

    # The tools the front matter pre-approves, as an Array of Strings.
    # RubyLLM reads the field but does not act on it.
    attr_reader :allowed_tools

    # The front matter's +metadata+, a Hash of Strings.
    attr_reader :metadata

    # The skill folder, as an absolute Pathname.
    attr_reader :path

    # The Markdown instructions that follow the front matter.
    attr_reader :instructions

    class << self
      # Returns the ordered skill directories. Append engine directories
      # with +<<+:
      #
      #   initializer "my_engine.skills" do
      #     RubyLLM::Skill.roots << MyEngine::Engine.root.join("app/skills")
      #   end
      #
      def roots
        @roots ||= Prompt::Roots.new { root }
      end

      def root # :nodoc:
        if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
          Rails.root.join('app/skills')
        else
          Pathname.new(Dir.pwd).join('app/skills')
        end
      end

      # Returns every skill directly under the skill roots. A skill in an
      # earlier root hides one with the same folder name in a later root.
      # Raises InvalidSkillError when a skill's +SKILL.md+ is invalid.
      def all
        folders = roots.flat_map { |root| skill_folders(Pathname.new(root)) }
        folders.uniq(&:basename).map { |folder| new(folder) }
      end

      # Returns the skill in the folder called +name+ under the first skill
      # root that has one. Underscores in a Symbol stand for hyphens, so
      # <tt>:pdf_processing</tt> finds +pdf-processing+. Raises
      # SkillNotFoundError when no root has it.
      #
      #   RubyLLM::Skill.find(:invoices)
      #
      def find(name)
        folder = name.is_a?(Symbol) ? name.to_s.tr('_', '-') : name.to_s
        found = (roots.map { |root| Pathname.new(root).join(folder) } if folder.match?(NAME_FORMAT))
                &.find { |path| path.join(FILE).file? }
        raise SkillNotFoundError, "No skill named #{folder} in #{roots.to_a.join(', ')}" unless found

        new(found)
      end

      # Returns +true+, +false+, or the skill names and paths in
      # +selection+, the arguments of Chat#with_skills. Raises
      # ArgumentError for +nil+, and for +true+ or +false+ with names.
      def selection(selection) # :nodoc:
        raise ArgumentError, 'skills cannot be nil; pass false to remove them' if selection.include?(nil)
        return true if selection.empty? || selection == [true]
        return false if selection == [false]
        raise ArgumentError, 'skills true and false take no skill names' if selection.intersect?([true, false])

        selection.flatten.freeze
      end

      # Returns the skills +selection+ names: Symbols are folders under the
      # skill roots, Strings and Pathnames are skill folders, and +true+ is
      # every skill under the roots.
      def resolve(selection) # :nodoc:
        case selection
        when true then all
        when false then []
        else selection.map { |entry| skill(entry) }
        end
      end

      # Returns +current+ with +added+, refusing two skills with one name.
      def merge(current, added) # :nodoc:
        added.each_with_object(current.dup) do |skill, skills|
          existing = skills.find { |other| other.name == skill.name }
          next skills << skill unless existing
          next if existing.path == skill.path

          raise ArgumentError, "Two skills are named #{skill.name}: #{existing.path} and #{skill.path}"
        end
      end

      private

      def skill(entry)
        case entry
        when Skill then entry
        when Symbol then find(entry)
        when String, Pathname then new(entry)
        else raise ArgumentError, "skills are Symbols, paths, or RubyLLM::Skill objects, got #{entry.inspect}"
        end
      end

      def skill_folders(root)
        return [] unless root.directory?

        root.children.select { |child| child.join(FILE).file? }.sort
      end
    end

    # Reads the skill in the folder at +path+. Raises SkillNotFoundError
    # when the folder has no +SKILL.md+, and InvalidSkillError when its
    # front matter breaks the Agent Skills specification. Front matter keys
    # the specification does not define are ignored.
    #
    #   RubyLLM::Skill.new("vendor/skills/pdf")
    #
    def initialize(path)
      @path = Pathname.new(File.realpath(path))
      file = @path.join(FILE)
      raise SkillNotFoundError, "#{file} not found" unless file.file?

      front_matter, @instructions = parse(file.read(encoding: 'UTF-8'))
      assign(front_matter)
    rescue Errno::ENOENT, Errno::ENOTDIR
      raise SkillNotFoundError, "No skill folder at #{path}"
    end

    # Returns the absolute path of the file at +relative+ inside the skill
    # folder. Raises ArgumentError when +relative+ leaves the folder, even
    # through a symbolic link, and Errno::ENOENT when nothing is there.
    def resolve_file(relative) # :nodoc:
      parts = relative.to_s.tr('\\', '/').split('/').reject { |part| part.empty? || part == '.' }
      if relative.to_s.start_with?('/', '\\') || relative.to_s.match?(/\A[A-Za-z]:/) || parts.include?('..')
        raise ArgumentError, "#{relative} is not a path inside the #{name} skill"
      end

      resolved = File.realpath(path.join(*parts))
      inside = resolved == path.to_s || resolved.start_with?(File.join(path.to_s, ''))
      raise ArgumentError, "#{relative} is not a path inside the #{name} skill" unless inside

      resolved
    end

    def inspect_attributes # :nodoc:
      { name:, description:, path: path.to_s }
    end

    private

    def parse(content)
      content = content.delete_prefix("\u{FEFF}")
      match = FRONT_MATTER.match(content)
      invalid('must start with YAML front matter between --- lines') unless match

      front_matter = YAML.safe_load(match[1], permitted_classes: [Date, Time])
      invalid('front matter must be a YAML mapping') unless front_matter.is_a?(Hash)
      [front_matter.transform_keys(&:to_s), match.post_match]
    rescue Psych::Exception => e
      invalid("front matter is not valid YAML: #{e.message}")
    end

    def assign(front_matter)
      @name = validated_name(front_matter['name'])
      @description = required_text(front_matter, 'description', MAX_DESCRIPTION)
      @license = optional_text(front_matter, 'license')
      @compatibility = optional_text(front_matter, 'compatibility', MAX_COMPATIBILITY)
      @allowed_tools = optional_text(front_matter, 'allowed-tools').to_s.split.freeze
      @metadata = validated_metadata(front_matter['metadata'])
    end

    def validated_name(value)
      name = required_text({ 'name' => value }, 'name', MAX_NAME).unicode_normalize(:nfkc)
      unless name == name.downcase && name.match?(NAME_FORMAT)
        invalid("name #{name.inspect} must be lowercase letters, digits, and single hyphens between them")
      end
      folder = path.basename.to_s.dup.force_encoding(Encoding::UTF_8).scrub.unicode_normalize(:nfkc)
      invalid("name #{name.inspect} must match its folder name, #{folder}") unless name == folder

      name
    end

    def required_text(front_matter, key, limit)
      value = front_matter[key]
      invalid("needs a #{key}") if value.nil? || (value.is_a?(String) && value.strip.empty?)

      optional_text(front_matter, key, limit)
    end

    def optional_text(front_matter, key, limit = nil)
      value = front_matter[key]
      return if value.nil?

      invalid("#{key} must be a string") unless value.is_a?(String)
      invalid("#{key} must not be empty") if value.strip.empty?
      invalid("#{key} must be at most #{limit} characters") if limit && value.length > limit
      value.strip
    end

    def validated_metadata(value)
      return {}.freeze if value.nil?

      invalid('metadata must be a mapping of strings') unless value.is_a?(Hash)
      value.to_h { |key, entry| [key.to_s, entry.to_s] }.freeze
    end

    def invalid(reason)
      raise InvalidSkillError, "#{path.join(FILE)} #{reason}"
    end
  end
end
