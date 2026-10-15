# frozen_string_literal: true

require 'rails/generators'

module RubyLLM
  module Generators
    # Generator for sandbox classes that code execution runs model code in.
    class SandboxGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      namespace 'ruby_llm:sandbox'

      desc 'Creates a sandbox class for code execution in app/sandboxes'

      def check_sandbox_class_collision
        class_collisions sandbox_class_name
      end

      def create_sandbox_file
        template 'sandbox.rb.tt', File.join('app/sandboxes', class_path, "#{sandbox_file_name}.rb")
      end

      def add_mxc_gem
        gemfile = File.join(destination_root, 'Gemfile')
        return unless File.exist?(gemfile)
        return if File.read(gemfile).match?(/^\s*gem\s+["']mxc["']/)

        gem 'mxc'
        say 'Run bundle install: sandboxes subclass MXC::Sandbox from the mxc gem.', :yellow
      end

      private

      def sandbox_class_name
        class_name.end_with?('Sandbox') ? class_name : "#{class_name}Sandbox"
      end

      def sandbox_file_name
        sandbox_class_name.demodulize.underscore
      end
    end
  end
end
