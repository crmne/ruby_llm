# frozen_string_literal: true

require 'fileutils'
require 'rails/generators'
require 'tmpdir'

module RubyLLM
  module Generators
    # Generator for skills in the open Agent Skills format.
    class SkillGenerator < Rails::Generators::Base
      namespace 'ruby_llm:skill'

      def self.exit_on_failure?
        true
      end

      argument :skill_name, type: :string, banner: 'name'
      argument :description, type: :string, banner: '"What it does and when to use it"'

      desc 'Creates a skill folder with its SKILL.md in app/skills'

      def check_skill
        Dir.mktmpdir do |root|
          folder = File.join(root, skill_name)
          FileUtils.mkdir_p(folder)
          File.write(File.join(folder, 'SKILL.md'), skill_markdown)
          RubyLLM::Skill.new(folder)
        end
      rescue RubyLLM::InvalidSkillError => e
        raise Thor::Error, e.message.sub(%r{\A\S*/SKILL\.md }, '')
      end

      def create_skill_file
        create_file File.join(skill_path, 'SKILL.md'), skill_markdown
      end

      private

      def skill_path
        File.join('app/skills', skill_name)
      end

      def skill_markdown
        "---\nname: #{skill_name}\ndescription: #{description.to_json}\n---\n"
      end
    end
  end
end
