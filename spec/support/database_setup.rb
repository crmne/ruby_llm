# frozen_string_literal: true

RSpec.shared_context 'with database setup' do
  before(:all) do
    # Ensure schema is loaded for this spec file
    ActiveRecord::Tasks::DatabaseTasks.load_schema_current

    # Load models from JSON and save to database
    if ActiveRecord::Base.connection.table_exists?(:models) && defined?(Model)
      RubyLLM.models.load_from_json!
      Model.save_to_database
    end
  end
end
