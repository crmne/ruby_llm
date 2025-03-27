# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'

RSpec.describe "Generator template files", type: :generator do
  # Use the actual template directory
  let(:template_dir) { "/Users/kieranklaassen/rails/ruby_llm/lib/generators/ruby_llm/install/templates" }
  
  describe "migration templates" do
    it "has expected migration template files" do
      expected_files = [
        "create_chats_migration.rb",
        "create_messages_migration.rb",
        "create_tool_calls_migration.rb"
      ]
      
      expected_files.each do |file|
        expect(File.exist?(File.join(template_dir, file))).to be(true), "Expected template file #{file} to exist"
      end
    end
    
    it "has proper migration content" do
      chat_migration = File.read(File.join(template_dir, "create_chats_migration.rb"))
      expect(chat_migration).to include("create_table :chats")
      expect(chat_migration).to include("t.string :model_id")
      
      message_migration = File.read(File.join(template_dir, "create_messages_migration.rb"))
      expect(message_migration).to include("create_table :messages")
      expect(message_migration).to include("t.references :chat")
      expect(message_migration).to include("t.string :role")
      expect(message_migration).to include("t.text :content")
      
      tool_call_migration = File.read(File.join(template_dir, "create_tool_calls_migration.rb"))
      expect(tool_call_migration).to include("create_table :tool_calls")
      expect(tool_call_migration).to include("t.references :message")
      expect(tool_call_migration).to include("t.string :tool_call_id")
      expect(tool_call_migration).to include("t.string :name")
      expect(tool_call_migration).to include("t.jsonb :arguments")
    end
  end
  
  describe "model templates" do
    it "has expected model template files" do
      expected_files = [
        "chat_model.rb",
        "message_model.rb",
        "tool_call_model.rb"
      ]
      
      expected_files.each do |file|
        expect(File.exist?(File.join(template_dir, file))).to be(true), "Expected template file #{file} to exist"
      end
    end
    
    it "has proper acts_as declarations in model templates" do
      chat_content = File.read(File.join(template_dir, "chat_model.rb"))
      expect(chat_content).to include("acts_as_chat")
      
      message_content = File.read(File.join(template_dir, "message_model.rb"))
      expect(message_content).to include("acts_as_message")
      
      tool_call_content = File.read(File.join(template_dir, "tool_call_model.rb"))
      expect(tool_call_content).to include("acts_as_tool_call")
    end
  end
  
  describe "initializer template" do
    it "has expected initializer template file" do
      expect(File.exist?(File.join(template_dir, "initializer.rb"))).to be(true)
    end
    
    it "has proper configuration content" do
      initializer_content = File.read(File.join(template_dir, "initializer.rb"))
      expect(initializer_content).to include("RubyLLM.configure do |config|")
      expect(initializer_content).to include("config.openai_api_key")
      expect(initializer_content).to include("ENV[\"OPENAI_API_KEY\"]")
      expect(initializer_content).to include("config.anthropic_api_key")
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
    end
  end
end