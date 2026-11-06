# frozen_string_literal: true

require 'rails/generators'

module RubyLLM
  module Generators
    # Generator for sandbox classes that code execution runs model code in.
    class SandboxGenerator < Rails::Generators::NamedBase
      INITIALIZER = 'config/initializers/ruby_llm.rb'
      CONFIGURE_BLOCK = /^RubyLLM\.configure do \|config\|\n/
      MXC_REQUIREMENT = '>= 0.4.1'

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

        existing = File.read(gemfile)[/^\s*gem\s+["']mxc["'].*$/]
        return warn_about_mxc_constraint(existing) if existing

        gem 'mxc', MXC_REQUIREMENT
        say 'Run bundle install: sandboxes subclass MXC::Sandbox from the mxc gem.', :yellow
      end

      def default_to_new_sandbox
        initializer = File.join(destination_root, INITIALIZER)
        return unless File.exist?(initializer)
        return if behavior == :invoke && File.read(initializer).match?(/^\s*config\.sandbox\s*(\|\|)?=/)

        unless File.read(initializer).match?(CONFIGURE_BLOCK)
          return say %(Set config.sandbox = "#{sandbox_class_name}" where you configure RubyLLM.), :yellow
        end

        inject_into_file INITIALIZER, %(  config.sandbox = "#{sandbox_class_name}"\n), after: CONFIGURE_BLOCK
      end

      private

      def warn_about_mxc_constraint(line)
        requirement = line[/["']mxc["']\s*,\s*["']([^"']+)["']/, 1]
        return if requirement.nil? || Gem::Requirement.new(requirement).satisfied_by?(Gem::Version.new('0.4.1'))

        say "Change the mxc line in your Gemfile: code execution needs mxc #{MXC_REQUIREMENT}.", :yellow
      end

      def sandbox_class_name
        class_name.end_with?('Sandbox') ? class_name : "#{class_name}Sandbox"
      end

      def sandbox_file_name
        sandbox_class_name.demodulize.underscore
      end
    end
  end
end
