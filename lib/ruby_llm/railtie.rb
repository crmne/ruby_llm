# frozen_string_literal: true

if defined?(Rails::Railtie)
  module RubyLLM
    # Rails integration for RubyLLM
    class Railtie < Rails::Railtie
      initializer 'ruby_llm.inflections' do
        ActiveSupport::Inflector.inflections(:en) do |inflect|
          inflect.acronym 'RubyLLM'
        end
      end

      initializer 'ruby_llm.instrumentation' do
        RubyLLM.config.instrumenter ||= ActiveSupport::Notifications
      end

      initializer 'ruby_llm.active_record' do
        ActiveSupport.on_load :active_record do
          require 'ruby_llm/active_record/payload_helpers'
          require 'ruby_llm/active_record/chat_methods'
          require 'ruby_llm/active_record/message_methods'
          require 'ruby_llm/active_record/model_methods'
          require 'ruby_llm/active_record/tool_call_methods'
          require 'ruby_llm/active_record/batch_methods'

          require 'ruby_llm/active_record/acts_as'
          ::ActiveRecord::Base.include RubyLLM::ActiveRecord::ActsAs
        end
      end

      rake_tasks do
        load 'tasks/ruby_llm.rake'
      end
    end
  end
end
