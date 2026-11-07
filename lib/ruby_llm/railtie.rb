# frozen_string_literal: true

if defined?(Rails::Railtie)
  module RubyLLM
    class Railtie < Rails::Railtie # :nodoc:
      ROOT = File.expand_path('../..', __dir__)
      JAVASCRIPTS = %w[ruby_llm/chat_message_controller.js ruby_llm/marked.js ruby_llm/dompurify.js].freeze

      initializer 'ruby_llm.inflections' do
        ActiveSupport::Inflector.inflections(:en) do |inflect|
          inflect.acronym 'RubyLLM'
        end
      end

      initializer 'ruby_llm.instrumentation' do
        RubyLLM.config.instrumenter ||= ActiveSupport::Notifications
      end

      initializer 'ruby_llm.skills', before: :setup_main_autoloader do
        Rails.autoloaders.main.ignore(*RubyLLM::Skill.roots)
      end

      initializer 'ruby_llm.active_record' do
        ActiveSupport.on_load :active_record do
          require 'ruby_llm/active_record/record'
          require 'ruby_llm/active_record/payload_helpers'
          require 'ruby_llm/active_record/model'
          require 'ruby_llm/active_record/tool_call'
          require 'ruby_llm/active_record/usage'
          require 'ruby_llm/active_record/batch'
          require 'ruby_llm/active_record/mcp_credential'
          require 'ruby_llm/active_record/provider_file'
          require 'ruby_llm/active_record/queued_message'
          require 'ruby_llm/active_record/chat_file'
          require 'ruby_llm/active_record/file_store'
          require 'ruby_llm/active_record/chat_methods'
          require 'ruby_llm/active_record/chat_files'
          require 'ruby_llm/active_record/chat_column_guard'
          require 'ruby_llm/active_record/message_methods'
          require 'ruby_llm/active_record/message_broadcasting'
          require 'ruby_llm/active_record/chunk_methods'

          require 'ruby_llm/active_record/acts_as'
          ::ActiveRecord::Base.include RubyLLM::ActiveRecord::ActsAs
          RubyLLM.config.mcp_credential_store ||= RubyLLM::ActiveRecord::MCPCredential
          RubyLLM::Accounting::Usage.ledger ||= RubyLLM::ActiveRecord::Usage
        end
      end

      initializer 'ruby_llm.active_storage' do
        ActiveSupport.on_load :active_storage_blob do
          after_destroy { RubyLLM::ActiveRecord::ProviderFile.forget_blob(self) }
        end
      end

      initializer 'ruby_llm.helpers' do
        ActiveSupport.on_load :action_view do
          require 'ruby_llm/active_record/chat_helper'
          include RubyLLM::ActiveRecord::ChatHelper
        end
      end

      initializer 'ruby_llm.assets' do |app|
        next unless app.config.respond_to?(:assets)

        app.config.assets.paths << File.join(ROOT, 'app/assets/javascripts')
        app.config.assets.precompile += JAVASCRIPTS
      end

      initializer 'ruby_llm.importmap', before: 'importmap' do |app|
        app.config.importmap.paths << File.join(ROOT, 'config/importmap.rb') if app.config.respond_to?(:importmap)
      end

      config.after_initialize do
        RubyLLM::Sandbox.verify(RubyLLM.sandbox) unless ENV['SECRET_KEY_BASE_DUMMY']
      end

      rake_tasks do
        load 'tasks/ruby_llm.rake'
      end
    end
  end
end
