# frozen_string_literal: true

require 'erb'
require 'pathname'

module RubyLLM
  class Prompt # :nodoc:
    # The ordered directories searched for prompt files. The application's
    # prompt directory is always first, so an application can override any
    # prompt an engine ships by placing a file at the same relative path.
    # Engines append their own directory in an initializer:
    #
    #   initializer "my_engine.prompts" do
    #     RubyLLM::Prompt.roots << MyEngine::Engine.root.join("app/prompts")
    #   end
    #
    class Roots
      include Enumerable

      def initialize(&default)
        @default = default
        @registered = []
      end

      def <<(path)
        @registered << Pathname.new(path)
        self
      end
      alias push <<

      def each(&)
        [@default.call, *@registered].each(&)
      end
    end

    attr_reader :name

    def initialize(name)
      @name = name.to_s
      @filename = @name.end_with?('.txt.erb') ? @name : "#{@name}.txt.erb"
    end

    def path
      @path ||= candidates.find { |candidate| File.exist?(candidate) } || candidates.first
    end

    def render(**locals)
      raise PromptNotFoundError, "Prompt file not found: #{path}" unless File.exist?(path)

      ERB.new(File.read(path)).result_with_hash(locals)
    end

    def self.render(name, **locals)
      new(name).render(**locals)
    end

    def self.roots
      @roots ||= Roots.new { root }
    end

    def self.root
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
