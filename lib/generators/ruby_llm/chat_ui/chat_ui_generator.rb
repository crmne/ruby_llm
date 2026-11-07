# frozen_string_literal: true

require 'rails/generators'
require_relative '../generator_helpers'

module RubyLLM
  module Generators
    # Generates a simple chat UI scaffold for RubyLLM
    class ChatUIGenerator < Rails::Generators::Base
      include RubyLLM::Generators::GeneratorHelpers

      source_root File.expand_path('templates', __dir__)

      MARKED_VERSION = '18.0.14'
      DOMPURIFY_VERSION = '3.4.16'

      namespace 'ruby_llm:chat_ui'

      argument :model_mappings, type: :array, default: [], banner: 'chat:ChatName message:MessageName ...'
      class_option :ui, type: :string, default: 'auto', enum: %w[scaffold tailwind auto],
                        desc: 'UI template style (scaffold, tailwind, auto)'

      desc "Creates a chat UI scaffold with Turbo streaming\n" \
           'Usage: bin/rails g ruby_llm:chat_ui [chat:ChatName] [message:MessageName] ...'

      def check_model_exists
        model_path = "app/models/#{message_model_name.underscore}.rb"
        return if app_file?(model_path)

        # Build the argument string for the install/upgrade commands
        args = []
        args << "chat:#{chat_model_name}" if chat_model_name != 'Chat'
        args << "message:#{message_model_name}" if message_model_name != 'Message'
        arg_string = args.any? ? " #{args.join(' ')}" : ''

        raise Thor::Error, <<~ERROR
          Model file not found: #{model_path}

          Please run the install generator first:
            bin/rails generate ruby_llm:install#{arg_string}
        ERROR
      end

      def check_hotwire
        return if File.read(File.join(destination_root, 'Gemfile')).match?(/^\s*gem[\s(]+["']turbo-rails["']/)

        say "\n  The chat UI runs on Hotwire, and this app doesn't have it, so its pages raise until you add it:", :red
        say '    bundle add turbo-rails stimulus-rails importmap-rails'
        say '    bin/rails importmap:install turbo:install stimulus:install'
        say '  An app from a plain rails new has them.', :red
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
        template 'views/chats/_approvals.html.erb', "app/views/#{chat_view_path}/_approvals.html.erb"
        template ui_template('views/chats/_files.html.erb'), "app/views/#{chat_view_path}/_files.html.erb"
        template ui_template('views/chats/_reply_error.html.erb'), "app/views/#{chat_view_path}/_reply_error.html.erb"

        # Approval views
        template ui_template('views/approvals/_approval.html.erb'), "app/views/#{approval_view_path}/_approval.html.erb"
        template 'views/approvals/create.turbo_stream.erb', "app/views/#{approval_view_path}/create.turbo_stream.erb"

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
        template ui_template('views/messages/_attachments.html.erb'),
                 "app/views/#{message_view_path}/_attachments.html.erb"
        template ui_template('views/messages/_form.html.erb'), "app/views/#{message_view_path}/_form.html.erb"
        template ui_template('views/messages/_queued_message.html.erb'),
                 "app/views/#{message_view_path}/_queued_message.html.erb"

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
        template 'controllers/approvals_controller.rb', "app/controllers/#{approval_view_path}_controller.rb"
        template 'controllers/queued_messages_controller.rb',
                 "app/controllers/#{queued_message_controller_path}_controller.rb"
      end

      def create_agent
        template 'agents/chat_agent.rb', "app/agents/#{chat_agent_class_name.underscore}.rb"
      end

      def create_jobs
        template 'jobs/chat_response_job.rb', "app/jobs/#{variable_name_for(chat_model_name)}_response_job.rb"
      end

      def create_system_test
        return unless app_file?('test/test_helper.rb')

        add_system_test_gems
        unless app_file?('test/application_system_test_case.rb')
          template 'test/application_system_test_case.rb', 'test/application_system_test_case.rb'
        end
        template 'test/system/chats_test.rb', "test/system/#{chat_model_name.underscore.pluralize}_test.rb"
        template 'test/agents/chat_agent_test.rb', "test/agents/#{chat_agent_class_name.underscore}_test.rb"
      end

      def create_helpers
        template 'helpers/messages_helper.rb', "app/helpers/#{message_model_name.underscore.pluralize}_helper.rb"
      end

      def create_javascript
        copy_file 'javascript/controllers/chat_message_controller.js',
                  'app/javascript/controllers/chat_message_controller.js'
      end

      def add_javascript_dependencies
        return unless behavior == :invoke

        if app_file?('config/importmap.rb')
          pin_javascript_dependencies
        elsif app_file?('package.json')
          say "\n  Add the chat UI's JavaScript dependencies, then register its Stimulus controller:", :yellow
          say "    yarn add #{javascript_packages}   (or: npm install #{javascript_packages})"
          say '    bin/rails stimulus:manifest:update'
        else
          say "\n  Your app has no JavaScript setup, so replies show as plain text until it has one.", :yellow
        end
        return if app_file?('app/javascript/controllers/index.js')

        say '  The chat UI renders replies with a Stimulus controller. Install Stimulus to use it:', :yellow
        say '    bin/rails stimulus:install'
      end

      def add_available_chat_models_to_application_controller
        path = 'app/controllers/application_controller.rb'
        return unless app_file?(path)
        return if File.read(File.join(destination_root, path)).include?('def available_chat_models')

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
          namespaces = chat_model_name.deconstantize.underscore.split('/')
          chat_resource = chat_model_name.demodulize.underscore.pluralize
          message_resource = message_model_name.demodulize.underscore.pluralize
          model_resource = model_model_name.demodulize.underscore.pluralize

          routes_content = <<~ROUTES.strip
            resources :#{model_resource}, only: [ :index, :show ], constraints: { id: /[^\\/]+/ } do
              collection do
                post :refresh
              end
            end
            resources :#{chat_resource} do
              post :cancel, on: :member
              resources :#{message_resource}, only: [ :create ]
              resources :queued_messages, only: [ :destroy ]
              resources :approvals, only: [ :create ]
            end
          ROUTES
          routes_content = namespaces.reverse.reduce(routes_content) do |routes, namespace|
            "namespace :#{namespace} do\n#{routes.indent(2)}\nend"
          end
          route routes_content
        else
          model_routes = <<~ROUTES.strip
            resources :#{model_resource_name}, only: [ :index, :show ], constraints: { id: /[^\\/]+/ } do
              collection do
                post :refresh
              end
            end
          ROUTES
          route model_routes
          chat_routes = <<~ROUTES.strip
            resources :#{chat_table_name} do
              post :cancel, on: :member
              resources :#{message_table_name}, only: [ :create ]
              resources :queued_messages, only: [ :destroy ]
              resources :approvals, only: [ :create ]
            end
          ROUTES
          route chat_routes
        end
      end

      def broadcast_messages
        remove_generated_message_code
        enable_message_broadcasting if behavior == :invoke
      end

      def add_head_to_layout
        path = 'app/views/layouts/application.html.erb'
        layout = File.join(destination_root, path)
        return unless File.exist?(layout)
        return if File.read(layout).include?('yield :head')

        inject_into_file path, "    <%= yield :head %>\n", before: %r{^\s*</head>}
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
        say "\n  Works now: streaming replies, Stop, file attachments, cost per reply, errors on the page."
        say "\n  Where it lives:"
        say "    The turn and its errors: app/jobs/#{variable_name_for(chat_model_name)}_response_job.rb"
        say "    Stop:                    #{chat_controller_class_name}#cancel"
        say "    Reply rendering:         app/views/#{message_model_name.underscore.pluralize}/_assistant.html.erb"
        say "    What the model can do:   app/agents/#{chat_agent_class_name.underscore}.rb"
        say "\n  Add to that agent, one line each, as you need them:"
        say "    file_store          the model reads, searches, and edits the chat's files with tools"
        say '    code_execution      the model runs code: bin/rails generate ruby_llm:sandbox Workspace first'
        say '                        With file_store, code reads attachments in ./attachments, or in the folder of'
        say "                        a store in a folder, and what it writes joins the chat's files."
        say '    mcp Linear          an MCP server: bin/rails generate ruby_llm:mcp Linear URL first'
        say '    tools WeatherTool   a tool: bin/rails generate ruby_llm:tool Weather first'
        if app_file?('test/test_helper.rb')
          say "\n  Check it with bin/rails test and bin/rails test:system (needs Chrome)."
        end
        say '  Use RubyLLM::TestHelper in your own tests, with no provider or key.'
        say "\n  Start your server and visit http://localhost:3000/#{url_path}", :cyan
        say "\n"
      end

      private

      def add_system_test_gems
        gemfile = File.read(File.join(destination_root, 'Gemfile'))
        missing = %w[capybara selenium-webdriver].reject { |name| gemfile.match?(/^\s*gem[\s(]+["']#{name}["']/) }
        return if missing.empty?

        gem_group(:test) { missing.each { |name| gem name } }
        Bundler.with_original_env { run 'bundle install --quiet' } if behavior == :invoke
      end

      def javascript_packages = "marked@#{MARKED_VERSION} dompurify@#{DOMPURIFY_VERSION}"
      def app_file?(path) = File.exist?(File.join(destination_root, path))

      def pin_javascript_dependencies
        importmap = File.read(File.join(destination_root, 'config/importmap.rb'))
        return if importmap.match?(/^pin "marked"/) && importmap.match?(/^pin "dompurify"/)
        return if run("bin/importmap pin #{javascript_packages}")

        say "\n  Pin the chat UI's JavaScript dependencies: bin/importmap pin #{javascript_packages}", :yellow
      end

      def approval_model_name
        return 'Approval' unless chat_model_name.include?('::')

        "#{chat_model_name.deconstantize}::Approval"
      end

      def approval_view_path = approval_model_name.underscore.pluralize
      def approval_controller_class_name = controller_class_name_for(approval_model_name)

      def queued_message_model_name
        return 'QueuedMessage' unless chat_model_name.include?('::')

        "#{chat_model_name.deconstantize}::QueuedMessage"
      end

      def queued_message_controller_path = queued_message_model_name.underscore.pluralize
      def queued_message_controller_class_name = controller_class_name_for(queued_message_model_name)
      def chat_agent_class_name = "#{chat_model_name}Agent"

      def application_agent_chat_class?
        File.read(File.join(destination_root, APPLICATION_AGENT_PATH))
            .match?(/^\s*chat_(?:class|model) #{Regexp.escape(chat_model_name)}\s*$/)
      end

      def application_agent_caching?
        File.read(File.join(destination_root, APPLICATION_AGENT_PATH)).match?(/^\s*caching\b/)
      end

      def message_helper_module_name
        if message_model_name.include?('::')
          "#{message_model_name.deconstantize}::#{message_model_name.demodulize.pluralize}Helper"
        else
          "#{message_model_name.pluralize}Helper"
        end
      end
    end
  end
end
