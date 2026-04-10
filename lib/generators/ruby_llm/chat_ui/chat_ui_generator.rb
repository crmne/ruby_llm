# frozen_string_literal: true

require 'rails/generators'
require_relative '../generator_helpers'

module RubyLLM
  module Generators
    # Generates a simple chat UI scaffold for RubyLLM
    class ChatUIGenerator < Rails::Generators::Base
      include RubyLLM::Generators::GeneratorHelpers

      source_root File.expand_path('templates', __dir__)

      namespace 'ruby_llm:chat_ui'

      argument :model_mappings, type: :array, default: [], banner: 'chat:ChatName message:MessageName ...'
      class_option :ui, type: :string, default: 'auto', enum: %w[scaffold tailwind auto],
                        desc: 'UI template style (scaffold, tailwind, auto)'

      desc 'Creates a chat UI scaffold with Turbo streaming\n' \
           'Usage: bin/rails g ruby_llm:chat_ui [chat:ChatName] [message:MessageName] ...'

      def check_model_exists
        model_path = "app/models/#{message_model_name.underscore}.rb"
        return if File.exist?(model_path)

        # Build the argument string for the install/upgrade commands
        args = []
        args << "chat:#{chat_model_name}" if chat_model_name != 'Chat'
        args << "message:#{message_model_name}" if message_model_name != 'Message'
        args << "model:#{model_model_name}" if model_model_name != 'Model'
        args << "tool_call:#{tool_call_model_name}" if tool_call_model_name != 'ToolCall'
        arg_string = args.any? ? " #{args.join(' ')}" : ''

        raise Thor::Error, <<~ERROR
          Model file not found: #{model_path}

          Please run the install generator first:
            bin/rails generate ruby_llm:install#{arg_string}

          Or if upgrading from <= 1.6.x, run the upgrade generator:
            bin/rails generate ruby_llm:upgrade_to_v1_7#{arg_string}
        ERROR
      end

      def create_views
        # Design contract:
        # - `scaffold` should stay close to Rails scaffold ERB output.
        # - `tailwind` should stay close to tailwindcss-rails scaffold output.
        # - Only small chat-specific affordances should be layered on top.
        # For namespaced models, use the proper Rails convention path
        chat_view_path = chat_model_name.underscore.pluralize
        message_view_path = message_model_name.underscore.pluralize
        model_view_path = model_model_name.underscore.pluralize

        # Chat views
        template ui_template('views/chats/index.html.erb'), "app/views/#{chat_view_path}/index.html.erb"
        template ui_template('views/chats/new.html.erb'), "app/views/#{chat_view_path}/new.html.erb"
        template ui_template('views/chats/show.html.erb'), "app/views/#{chat_view_path}/show.html.erb"
        template ui_template('views/chats/_chat.html.erb'),
                 "app/views/#{chat_view_path}/_#{chat_model_name.demodulize.underscore}.html.erb"
        template ui_template('views/chats/_form.html.erb'), "app/views/#{chat_view_path}/_form.html.erb"

        # Message views
        template ui_template('views/messages/_assistant.html.erb'), "app/views/#{message_view_path}/_assistant.html.erb"
        template ui_template('views/messages/_user.html.erb'), "app/views/#{message_view_path}/_user.html.erb"
        template ui_template('views/messages/_system.html.erb'), "app/views/#{message_view_path}/_system.html.erb"
        template ui_template('views/messages/_tool.html.erb'), "app/views/#{message_view_path}/_tool.html.erb"
        template ui_template('views/messages/_error.html.erb'), "app/views/#{message_view_path}/_error.html.erb"
        template ui_template('views/messages/_tool_calls.html.erb'),
                 "app/views/#{message_view_path}/_tool_calls.html.erb"
        empty_directory "app/views/#{message_view_path}/tool_calls"
        template ui_template('views/messages/tool_calls/_default.html.erb'),
                 "app/views/#{message_view_path}/tool_calls/_default.html.erb"
        empty_directory "app/views/#{message_view_path}/tool_results"
        template ui_template('views/messages/tool_results/_default.html.erb'),
                 "app/views/#{message_view_path}/tool_results/_default.html.erb"
        template ui_template('views/messages/create.turbo_stream.erb'),
                 "app/views/#{message_view_path}/create.turbo_stream.erb"
        template ui_template('views/messages/_content.html.erb'), "app/views/#{message_view_path}/_content.html.erb"
        template ui_template('views/messages/_form.html.erb'), "app/views/#{message_view_path}/_form.html.erb"

        # Model views
        template ui_template('views/models/index.html.erb'), "app/views/#{model_view_path}/index.html.erb"
        template ui_template('views/models/show.html.erb'), "app/views/#{model_view_path}/show.html.erb"
        template ui_template('views/models/_model.html.erb'),
                 "app/views/#{model_view_path}/_#{model_model_name.demodulize.underscore}.html.erb"
      end

      def create_controllers
        # For namespaced models, use the proper Rails convention path
        chat_controller_path = chat_model_name.underscore.pluralize
        message_controller_path = message_model_name.underscore.pluralize
        model_controller_path = model_model_name.underscore.pluralize

        template 'controllers/chats_controller.rb', "app/controllers/#{chat_controller_path}_controller.rb"
        template 'controllers/messages_controller.rb', "app/controllers/#{message_controller_path}_controller.rb"
        template 'controllers/models_controller.rb', "app/controllers/#{model_controller_path}_controller.rb"
      end

      def create_jobs
        template 'jobs/chat_response_job.rb', "app/jobs/#{variable_name_for(chat_model_name)}_response_job.rb"
      end

      def create_helpers
        template 'helpers/messages_helper.rb', "app/helpers/#{message_model_name.underscore.pluralize}_helper.rb"
      end

      def add_available_chat_models_to_application_controller
        path = 'app/controllers/application_controller.rb'
        return unless File.exist?(path)

        application_controller = File.read(path)
        return if application_controller.include?('def available_chat_models')

        inject_into_file path, <<-RUBY, before: /^end\s*\z/
  private

  def available_chat_models
    RubyLLM.models.chat_models.all
           .sort_by { |model| [ model.provider.to_s, model.name.to_s ] }
  end
        RUBY
      end

      def add_routes
        # For namespaced models, use Rails convention with namespace blocks
        if chat_model_name.include?('::')
          namespace = chat_model_name.deconstantize.underscore
          chat_resource = chat_model_name.demodulize.underscore.pluralize
          message_resource = message_model_name.demodulize.underscore.pluralize
          model_resource = model_model_name.demodulize.underscore.pluralize

          routes_content = <<~ROUTES.strip
            namespace :#{namespace} do
              resources :#{model_resource}, only: [ :index, :show ] do
                collection do
                  post :refresh
                end
              end
              resources :#{chat_resource} do
                resources :#{message_resource}, only: [ :create ]
              end
            end
          ROUTES
          route routes_content
        else
          model_routes = <<~ROUTES.strip
            resources :#{model_table_name}, only: [ :index, :show ] do
              collection do
                post :refresh
              end
            end
          ROUTES
          route model_routes
          chat_routes = <<~ROUTES.strip
            resources :#{chat_table_name} do
              resources :#{message_table_name}, only: [ :create ]
            end
          ROUTES
          route chat_routes
        end
      end

      def add_broadcasting_to_message_model
        msg_var = variable_name_for(message_model_name)
        chat_var = variable_name_for(chat_model_name)
        msg_path = message_model_name.underscore

        # For namespaced models, we need the association name which might be different
        # e.g., for LLM::Message, the chat association might be :llm_chat
        chat_association = chat_table_name.singularize

        broadcasting_callbacks = <<-RUBY

  broadcasts_to ->(#{msg_var}) { "#{chat_var}_\#{#{msg_var}.#{chat_association}_id}" }, inserts_by: :append

  def broadcast_append_chunk(content)
    broadcast_append_to "#{chat_var}_\#{#{chat_association}_id}",
      target: "#{msg_var}_\#{id}_content",
      content: ERB::Util.html_escape(content.to_s)
  end
        RUBY

        inject_into_file "app/models/#{msg_path}.rb", before: "end\n" do
          broadcasting_callbacks
        end
      rescue Errno::ENOENT
        say "#{message_model_name} model not found. Add broadcasting code to your model.", :yellow
        say broadcasting_callbacks, :yellow
      end

      def display_post_install_message
        return unless behavior == :invoke

        # Show the correct URL based on whether models are namespaced
        url_path = if chat_model_name.include?('::')
                     chat_model_name.underscore.pluralize
                   else
                     chat_table_name
                   end

        say "\n  ✅ Chat UI installed!", :green
        say "  UI template: #{ui_variant}", :cyan
        say "\n  Start your server and visit http://localhost:3000/#{url_path}", :cyan
        say "\n"
      end

      private

      def ui_variant
        @ui_variant ||= case options[:ui]
                        when 'tailwind'
                          :tailwind
                        when 'auto'
                          tailwind_available? ? :tailwind : :scaffold
                        else
                          :scaffold
                        end
      end

      def ui_template(template_path)
        return template_path unless ui_variant == :tailwind

        # Keep Tailwind templates as a separate set so we can mirror Rails/Tailwind
        # scaffold conventions without complicating scaffold templates.
        tailwind_template = "tailwind/#{template_path}"
        File.exist?(File.join(self.class.source_root, "#{tailwind_template}.tt")) ? tailwind_template : template_path
      end

      def message_helper_module_name
        if message_model_name.include?('::')
          "#{message_model_name.deconstantize}::#{message_model_name.demodulize.pluralize}Helper"
        else
          "#{message_model_name.pluralize}Helper"
        end
      end

      def tailwind_available?
        Rails.root.join('app/assets/tailwind/application.css').exist? ||
          Rails.root.join('config/tailwind.config.js').exist? ||
          gem_in_bundle?('tailwindcss-rails') ||
          gem_in_bundle?('cssbundling-rails')
      end

      def gem_in_bundle?(gem_name)
        gemfile_path = Rails.root.join('Gemfile')
        lockfile_path = Rails.root.join('Gemfile.lock')

        [gemfile_path, lockfile_path].any? do |path|
          path.exist? && path.read.include?(gem_name)
        end
      end
    end
  end
end
