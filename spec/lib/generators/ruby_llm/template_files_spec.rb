# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'

RSpec.describe "Generator template files", type: :generator do
  # Use the actual template directory
  let(:template_dir) { "/Users/kieranklaassen/rails/ruby_llm/lib/generators/ruby_llm/install/templates" }
  
  describe "migration templates" do
    it "has expected migration template files" do
      expected_files = [
        "create_chats_migration.rb.tt",
        "create_messages_migration.rb.tt",
        "create_tool_calls_migration.rb.tt"
      ]
      
      expected_files.each do |file|
        expect(File.exist?(File.join(template_dir, file))).to be(true), "Expected template file #{file} to exist"
      end
    end
    
    it "has proper migration content" do
      chat_migration = File.read(File.join(template_dir, "create_chats_migration.rb.tt"))
      expect(chat_migration).to include("create_table :chats")
      expect(chat_migration).to include("t.string :model_id")
      
      message_migration = File.read(File.join(template_dir, "create_messages_migration.rb.tt"))
      expect(message_migration).to include("create_table :messages")
      expect(message_migration).to include("t.references :chat")
      expect(message_migration).to include("t.string :role")
      expect(message_migration).to include("t.text :content")
      expect(message_migration).to include("t.references :tool_call")
      
      tool_call_migration = File.read(File.join(template_dir, "create_tool_calls_migration.rb.tt"))
      expect(tool_call_migration).to include("create_table :tool_calls")
      expect(tool_call_migration).to include("t.string :tool_call_id")
      expect(tool_call_migration).to include("t.string :name")
      
      # Should check for database-agnostic JSON handling
      expect(tool_call_migration).to include("if postgresql?")
      expect(tool_call_migration).to include("t.jsonb :arguments")
      expect(tool_call_migration).to include("else")
      expect(tool_call_migration).to include("t.json :arguments") 
      expect(tool_call_migration).to include("end")
    end
  end
  
  describe "model templates" do
    it "has expected model template files" do
      expected_files = [
        "chat_model.rb.tt",
        "message_model.rb.tt",
        "tool_call_model.rb.tt"
      ]
      
      expected_files.each do |file|
        expect(File.exist?(File.join(template_dir, file))).to be(true), "Expected template file #{file} to exist"
      end
    end
    
    it "has proper acts_as declarations in model templates" do
      chat_content = File.read(File.join(template_dir, "chat_model.rb.tt"))
      expect(chat_content).to include("acts_as_chat")
      
      message_content = File.read(File.join(template_dir, "message_model.rb.tt"))
      expect(message_content).to include("acts_as_message")
      
      tool_call_content = File.read(File.join(template_dir, "tool_call_model.rb.tt"))
      expect(tool_call_content).to include("acts_as_tool_call")
    end
  end
  
  describe "initializer template" do
    it "has expected initializer template file" do
      expect(File.exist?(File.join(template_dir, "initializer.rb.tt"))).to be(true)
    end
    
    it "has proper configuration content" do
      initializer_content = File.read(File.join(template_dir, "initializer.rb.tt"))
      expect(initializer_content).to include("RubyLLM.configure do |config|")
      expect(initializer_content).to include("config.openai_api_key")
      expect(initializer_content).to include("ENV[\"OPENAI_API_KEY\"]")
      expect(initializer_content).to include("config.anthropic_api_key")
    end
  end
  
  describe "README template" do
    it "has a README template file" do
      expect(File.exist?(File.join(template_dir, "README.md"))).to be(true)
    end
    
    it "has helpful post-installation instructions" do
      readme_content = File.read(File.join(template_dir, "README.md"))
      expect(readme_content).to include("RubyLLM Rails Setup Complete")
      expect(readme_content).to include("Run migrations")
      expect(readme_content).to include("rails db:migrate")
      expect(readme_content).to include("Set your API keys")
      expect(readme_content).to include("Start using RubyLLM in your code")
      expect(readme_content).to include("For streaming responses")
    end
  end
  
  describe "generator file structure" do
    it "has proper directory structure" do
      generator_file = "/Users/kieranklaassen/rails/ruby_llm/lib/generators/ruby_llm/install_generator.rb"
      expect(File.exist?(generator_file)).to be(true)
      
      generator_content = File.read(generator_file)
      expect(generator_content).to include("class InstallGenerator < Rails::Generators::Base")
      expect(generator_content).to include("include Rails::Generators::Migration")
      expect(generator_content).to include("def create_migration_files")
      expect(generator_content).to include("def create_model_files")
      expect(generator_content).to include("def create_initializer")
      expect(generator_content).to include("def show_readme")
    end
    
    it "creates migrations in the correct order" do
      generator_file = "/Users/kieranklaassen/rails/ruby_llm/lib/generators/ruby_llm/install_generator.rb"
      generator_content = File.read(generator_file)
      
      # Check for correct order in migration creation
      # 1. First chats table (no dependencies)
      # 2. Then tool_calls table (will be referenced by messages)
      # 3. Finally messages table (depends on both chats and tool_calls)
      
      # Simply check the order of template calls
      # Chats should come before tool_calls, which should come before messages
      chats_position = generator_content.index('create_chats.rb')
      tool_calls_position = generator_content.index('create_tool_calls.rb') 
      messages_position = generator_content.index('create_messages.rb')
      
      # Verify order: chats -> tool_calls -> messages
      expect(chats_position).to be < tool_calls_position
      expect(tool_calls_position).to be < messages_position
      
      # Also test that the method enforces sequential timestamps
      expect(generator_content).to include("@migration_number = Time.now.utc.strftime")
      expect(generator_content).to include("@migration_number = (@migration_number.to_i + 1).to_s")
      expect(generator_content).to include("@migration_number = (@migration_number.to_i + 2).to_s")
    end
  end
  
  describe "database adapter detection" do
    it "has proper postgresql detection method" do
      generator_file = "/Users/kieranklaassen/rails/ruby_llm/lib/generators/ruby_llm/install_generator.rb"
      generator_content = File.read(generator_file)
      
      # Check proper postgresql? method implementation
      expect(generator_content).to include("def postgresql?")
      expect(generator_content).to include("ActiveRecord::Base.connection.adapter_name.downcase.include?(\"postgresql\")")
      expect(generator_content).to include("rescue")
      expect(generator_content).to include("false")
    end
  end
end