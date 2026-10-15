# frozen_string_literal: true

require 'rails/generators'

module RubyLLM
  module Generators
    # Generator for evaluations and their datasets.
    class EvaluationGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      namespace 'ruby_llm:evaluation'

      desc 'Creates an evaluation class and its dataset in app/evals'

      def check_evaluation_class_collision
        class_collisions evaluation_class_name
      end

      def create_evaluation_file
        template 'evaluation.rb.tt', File.join('app/evals', class_path, "#{evaluation_file_name}.rb")
      end

      def create_dataset_file
        template 'evaluation.yml.tt', File.join('app/evals', class_path, "#{evaluation_file_name}.yml")
      end

      private

      def evaluation_class_name
        class_name.end_with?('Evaluation') ? class_name : "#{class_name}Evaluation"
      end

      def evaluation_file_name
        evaluation_class_name.demodulize.underscore
      end

      def agent_class_name
        name = "#{evaluation_class_name.delete_suffix('Evaluation')}Agent"
        name if File.exist?(File.join(destination_root, 'app/agents', "#{name.underscore}.rb"))
      end
    end
  end
end
