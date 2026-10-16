# frozen_string_literal: true

require 'erb'
require 'pathname'

module RubyLLM
  # Resolves prompt templates from the application and registered engine directories.
  class Prompt
    # The ordered directories searched for prompt files, and for skills
    # through Skill.roots. The application's directory is always first, so
    # an application can override any prompt or skill an engine ships by
    # placing its own at the same relative path. Engines append their own
    # directories in an initializer:
    #
    #   initializer "my_engine.prompts" do
    #     RubyLLM::Prompt.roots << MyEngine::Engine.root.join("app/prompts")
    #     RubyLLM::Skill.roots << MyEngine::Engine.root.join("app/skills")
    #   end
    #
    class Roots
      include Enumerable

      def initialize(&default) # :nodoc:
        @default = default
        @registered = []
      end

      # Appends a prompt directory and returns +self+.
      def <<(path)
        @registered << Pathname.new(path)
        self
      end
      alias push <<

      # Yields each prompt directory in lookup order. Returns an Enumerator without a block.
      def each(&)
        [@default.call, *@registered].each(&)
      end
    end

    attr_reader :name # :nodoc:

    def initialize(name) # :nodoc:
      @name = name.to_s
      @filename = @name.end_with?('.txt.erb') ? @name : "#{@name}.txt.erb"
    end

    def path # :nodoc:
      @path ||= candidates.find { |candidate| File.exist?(candidate) } || candidates.first
    end

    def render(**locals) # :nodoc:
      raise PromptNotFoundError, "Prompt file not found: #{path}" unless File.exist?(path)

      ERB.new(File.read(path, encoding: Encoding::UTF_8), trim_mode: '-').result(Context.new(self, locals).scope)
    end

    def self.render(name, **locals) # :nodoc:
      new(name).render(**locals)
    end

    # Returns the ordered prompt directories. Append engine directories with +<<+.
    def self.roots
      @roots ||= Roots.new { root }
    end

    def self.root # :nodoc:
      if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
        Rails.root.join('app/prompts')
      else
        Pathname.new(Dir.pwd).join('app/prompts')
      end
    end

    private

    def candidates
      self.class.roots.map { |root| Pathname.new(root).join(@filename) }
    end
  end
end
