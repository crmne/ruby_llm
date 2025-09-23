# frozen_string_literal: true

require 'rails/generators'

module RubyLLM
  module Generators
    # Generates a simple chat UI scaffold for RubyLLM
    class ChatUIGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      namespace 'ruby_llm:chat_ui'

      argument :model_mappings, type: :array, default: [], banner: 'chat:ChatName message:MessageName ...'

      desc 'Creates a chat UI scaffold with Turbo streaming\n' \
           'Usage: rails g ruby_llm:chat_ui [chat:ChatName] [message:MessageName] ...'

      def parse_model_mappings
        @model_names = {
          chat: 'Chat',
          message: 'Message',
          tool_call: 'ToolCall',
          model: 'Model'
        }

        model_mappings.each do |mapping|
          if mapping.include?(':')
            key, value = mapping.split(':', 2)
            @model_names[key.to_sym] = value.classify
          end
        end

        @model_names
      end

      %i[chat message model tool_call].each do |type|
        define_method("#{type}_model_name") do
          @model_names ||= parse_model_mappings
          @model_names[type]
        end

        define_method("#{type}_table_name") do
          table_name_for(send("#{type}_model_name"))
        end
      end

      def create_views
        # Chat views
        template 'views/chats/index.html.erb', "app/views/#{chat_table_name}/index.html.erb"
        template 'views/chats/new.html.erb', "app/views/#{chat_table_name}/new.html.erb"
        template 'views/chats/show.html.erb', "app/views/#{chat_table_name}/show.html.erb"
        template 'views/chats/_chat.html.erb',
                 "app/views/#{chat_table_name}/_#{chat_model_name.underscore}.html.erb"
        template 'views/chats/_form.html.erb', "app/views/#{chat_table_name}/_form.html.erb"

        # Message views
        template 'views/messages/_message.html.erb',
                 "app/views/#{message_table_name}/_#{message_model_name.underscore}.html.erb"
        template 'views/messages/_tool_calls.html.erb',
                 "app/views/#{message_table_name}/_#{tool_call_model_name.tableize}.html.erb"
        template 'views/messages/_content.html.erb', "app/views/#{message_table_name}/_content.html.erb"
        template 'views/messages/_form.html.erb', "app/views/#{message_table_name}/_form.html.erb"
        template 'views/messages/create.turbo_stream.erb',
                 "app/views/#{message_table_name}/create.turbo_stream.erb"

        # Model views
        template 'views/models/index.html.erb', "app/views/#{model_table_name}/index.html.erb"
        template 'views/models/show.html.erb', "app/views/#{model_table_name}/show.html.erb"
        template 'views/models/_model.html.erb',
                 "app/views/#{model_table_name}/_#{model_model_name.underscore}.html.erb"
      end

      def create_controllers
        template 'controllers/chats_controller.rb', "app/controllers/#{chat_table_name}_controller.rb"
        template 'controllers/messages_controller.rb', "app/controllers/#{message_table_name}_controller.rb"
        template 'controllers/models_controller.rb', "app/controllers/#{model_table_name}_controller.rb"
      end

      def create_jobs
        template 'jobs/chat_response_job.rb', "app/jobs/#{chat_model_name.underscore}_response_job.rb"
      end

      def add_routes
        model_routes = <<~ROUTES.strip
          resources :#{model_table_name}, only: [:index, :show] do
            collection do
              post :refresh
            end
          end
        ROUTES
        route model_routes
        chat_routes = <<~ROUTES.strip
          resources :#{chat_table_name} do
            resources :#{message_table_name}, only: [:create]
          end
        ROUTES
        route chat_routes
      end

      def add_broadcasting_to_message_model
        msg_var = message_model_name.underscore
        chat_var = chat_model_name.underscore
        broadcasting_code = "broadcasts_to ->(#{msg_var}) { \"#{chat_var}_\#{#{msg_var}.#{chat_var}_id}\" }"

        broadcast_append_chunk_method = <<-RUBY

  def broadcast_append_chunk(content)
    broadcast_append_to "#{chat_var}_\#{#{chat_var}_id}",
      target: "#{msg_var}_\#{id}_content",
      partial: "#{message_table_name}/content",
      locals: { content: content }
  end
        RUBY

        inject_into_file "app/models/#{msg_var}.rb", before: "end\n" do
          "  #{broadcasting_code}\n#{broadcast_append_chunk_method}"
        end
      rescue Errno::ENOENT
        say "#{message_model_name} model not found. Add broadcasting code to your model.", :yellow
        say "  #{broadcasting_code}", :yellow
        say broadcast_append_chunk_method, :yellow
      end

      def display_post_install_message
        return unless behavior == :invoke

        say "\n  ✅ Chat UI installed!", :green
        say "\n  Start your server and visit http://localhost:3000/#{chat_table_name}", :cyan
        say "\n"
      end

      private

      def table_name_for(model_name)
        # Convert namespaced model names to proper table names
        # e.g., "Assistant::Chat" -> "assistant_chats" (not "assistant/chats")
        model_name.underscore.pluralize.tr('/', '_')
      end
    end
  end
end
