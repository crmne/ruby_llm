# frozen_string_literal: true

module RubyLLM
  # Renders ERB prompt templates from the prompts directory.
  class Prompt
    attr_reader :name, :path

    def initialize(name)
      @name = name.to_s
      @path = self.class.root.join(
        @name.end_with?('.txt.erb') ? @name : "#{@name}.txt.erb"
      )
    end

    def render(**locals)
      raise PromptNotFoundError, "Prompt file not found: #{@path}" unless File.exist?(@path)

      ERB.new(File.read(@path)).result_with_hash(locals)
    end

    def self.render(name, **locals)
      new(name).render(**locals)
    end

    def self.root
      if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
        Rails.root.join('app/prompts')
      else
        Pathname.new(Dir.pwd).join('app/prompts')
      end
    end
  end
end
