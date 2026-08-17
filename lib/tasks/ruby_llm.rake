# frozen_string_literal: true

namespace :ruby_llm do
  desc 'Load the selected model registry into the database'
  task load_models: :environment do
    # Rails 8.1 loads ActiveRecord::Base lazily, so outside a runner or console
    # the :active_record load hook that defines RubyLLM::ActiveRecord::Model
    # never fires. Requiring it here runs the hook; it is a no-op if it already did.
    require 'active_record/base'

    RubyLLM.models.load_from_json!
    model_class = RubyLLM::ActiveRecord::Model
    model_class.save_to_database
    puts "✅ Loaded #{model_class.count} models into database"
  end
end
