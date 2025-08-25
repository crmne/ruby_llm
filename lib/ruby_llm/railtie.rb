# frozen_string_literal: true

module RubyLLM
  # Rails integration for RubyLLM
  class Railtie < Rails::Railtie
    initializer 'ruby_llm.active_record' do
      ActiveSupport.on_load :active_record do
        include RubyLLM::ActiveRecord::ActsAs
      end
    end

    generators do
      require 'generators/ruby_llm/install_generator'
    end
  end
end
