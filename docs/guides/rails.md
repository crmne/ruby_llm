

⸻

layout: default
title: Rails Integration
parent: Guides
nav_order: 5
permalink: /guides/rails

Rails Integration

{: .no_toc }

RubyLLM offers seamless integration with Ruby on Rails applications through helpers for ActiveRecord models. This allows you to easily persist chat conversations, including messages and tool interactions, directly in your database.
{: .fs-6 .fw-300 }

Table of contents

{: .no_toc .text-delta }
	1.	TOC
{:toc}

⸻

After reading this guide, you will know:
	•	How to set up ActiveRecord models for persisting chats and messages.
	•	How to use acts_as_chat and acts_as_message.
	•	How chat interactions automatically persist data.
	•	A basic approach for integrating streaming responses with Hotwire/Turbo Streams.

Setup

Using the Generator (Recommended)

The easiest way to set up RubyLLM with Rails is to use the built‑in generator:

rails generate ruby_llm:install

This will automatically:
	1.	Create the necessary migrations for chats, messages, and tool calls.
	2.	Create model files with appropriate acts_as_* methods.
	3.	Set up proper relationships between models.

After running the generator, simply run the migrations:

rails db:migrate

Manual Setup

If you prefer to set up manually or need to customize the implementation, follow these steps.

1. Create Migrations

First, generate migrations for your Chat and Message models. You’ll also need a ToolCall model if you plan to use [Tools]({% link guides/tools.md %}).

# Generate basic models and migrations
rails g model Chat model_id:string user:references           # Example user association
rails g model Message chat:references role:string content:text model_id:string input_tokens:integer output_tokens:integer tool_call:references
rails g model ToolCall message:references tool_call_id:string:index name:string arguments:jsonb

Adjust the migrations as needed (e.g., null: false constraints, and jsonb type for PostgreSQL).

Then complete the migration files:

# db/migrate/YYYYMMDDHHMMSS_create_chats.rb
class CreateChats < ActiveRecord::Migration[7.1]
  def change
    create_table :chats do |t|
      t.string :model_id
      t.references :user # Optional: Example association
      t.timestamps
    end
  end
end

# db/migrate/YYYYMMDDHHMMSS_create_messages.rb
class CreateMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :messages do |t|
      t.references :chat, null: false, foreign_key: true
      t.string :role
      t.text :content
      # Optional fields for tracking usage/metadata
      t.string :model_id
      t.integer :input_tokens
      t.integer :output_tokens
      t.references :tool_call # Links tool result message to the initiating call
      t.timestamps
    end
  end
end

# db/migrate/YYYYMMDDHHMMSS_create_tool_calls.rb
# (Only needed if using tools)
class CreateToolCalls < ActiveRecord::Migration[7.1]
  def change
    create_table :tool_calls do |t|
      t.references :message, null: false, foreign_key: true # Assistant message making the call
      t.string :tool_call_id, null: false, index: { unique: true } # Provider's ID for the call
      t.string :name, null: false
      t.jsonb :arguments, default: {} # Use jsonb for PostgreSQL
      t.timestamps
    end
  end
end

Run the migrations:

rails db:migrate

2. Set Up Models

Create the model classes and include the RubyLLM helpers in your ActiveRecord models:

# app/models/chat.rb
class Chat < ApplicationRecord
  # Includes methods like ask, with_tool, with_instructions, etc.
  # Automatically persists associated messages and tool calls.
  acts_as_chat # Assumes Message and ToolCall model names

  # --- Add your standard Rails model logic below ---
  belongs_to :user, optional: true # Example
  validates :model_id, presence: true # Example
end

# app/models/message.rb
class Message < ApplicationRecord
  # Provides methods like tool_call?, tool_result?
  acts_as_message # Ass