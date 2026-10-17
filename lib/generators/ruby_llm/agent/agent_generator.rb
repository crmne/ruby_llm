# frozen_string_literal: true

require 'rails/generators'

module RubyLLM
  module Generators
    # Generator for RubyLLM agent classes and prompt files.
    class AgentGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      namespace 'ruby_llm:agent'

      desc 'Creates a RubyLLM agent class and default instructions prompt'

      def create_agent_file
        template 'agent.rb.tt', File.join('app/agents', class_path, "#{agent_file_name}.rb")
      end

      def create_prompt_file
        empty_directory File.join('app/prompts', agent_prompt_path)
        template 'instructions.txt.erb.tt', File.join('app/prompts', agent_prompt_path, 'instructions.txt.erb')
      end

      private

      def agent_class_name
        class_name.end_with?('Agent') ? class_name : "#{class_name}Agent"
      end

      def agent_file_name
        agent_class_name.demodulize.underscore
      end

      # Mirrors RubyLLM::Agent's prompt lookup, which ignores the app's inflections.
      def agent_prompt_path
        RubyLLM::Support::Utils.underscore(agent_class_name.gsub('::', '/')).tr('-', '_')
      end

      def application_agent?
        File.exist?(File.join(destination_root, 'app/agents/application_agent.rb'))
      end
    end
  end
end
