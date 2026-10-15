# frozen_string_literal: true

require 'rails/generators'

module RubyLLM
  module Generators
    # Generator for judge classes that ask judgment models for probabilities,
    # choices, and scores.
    class JudgeGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      namespace 'ruby_llm:judge'

      desc 'Creates a judge class in app/judges'

      def check_judge_class_collision
        class_collisions judge_class_name
      end

      def create_judge_file
        template 'judge.rb.tt', File.join('app/judges', class_path, "#{judge_file_name}.rb")
      end

      private

      def judge_class_name
        class_name.end_with?('Judge') ? class_name : "#{class_name}Judge"
      end

      def judge_file_name
        judge_class_name.demodulize.underscore
      end
    end
  end
end
