---
layout: default
title: Rails Integration
parent: Agent SDK
nav_order: 3
permalink: /agent-sdk/rails
---

# Rails Integration

Integrate the Agent SDK into your Rails application with background jobs, Turbo Streams, and ActiveRecord persistence.

## Setup

### 1. Install Dependencies

```ruby
# Gemfile
gem 'ruby_llm'
gem 'sidekiq'  # or any ActiveJob adapter
```

```bash
bundle install
```

### 2. Create Migrations

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_agent_sessions.rb
class CreateAgentSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :agent_sessions do |t|
      t.references :user, foreign_key: true
      t.string :claude_session_id
      t.string :status, default: 'pending'  # pending, running, completed, failed
      t.string :model_id
      t.text :prompt
      t.text :result
      t.decimal :total_cost_usd, precision: 10, scale: 6
      t.integer :num_turns
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :agent_sessions, :claude_session_id
    add_index :agent_sessions, :status
  end
end

# db/migrate/YYYYMMDDHHMMSS_create_agent_messages.rb
class CreateAgentMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :agent_messages do |t|
      t.references :agent_session, null: false, foreign_key: true
      t.string :message_type  # assistant, user, result, system
      t.string :subtype
      t.text :content
      t.string :uuid
      t.jsonb :tool_calls, default: []
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :agent_messages, :uuid
    add_index :agent_messages, :message_type
  end
end
```

```bash
rails db:migrate
```

### 3. Create Models

```ruby
# app/models/agent_session.rb
class AgentSession < ApplicationRecord
  belongs_to :user, optional: true
  has_many :agent_messages, dependent: :destroy

  enum :status, {
    pending: 'pending',
    running: 'running',
    completed: 'completed',
    failed: 'failed'
  }

  scope :recent, -> { order(created_at: :desc).limit(20) }

  def run!(prompt = self.prompt)
    update!(status: :running, prompt: prompt)
    AgentJob.perform_later(id, prompt)
  end

  def resume!(prompt)
    AgentJob.perform_later(id, prompt, resume: true)
  end

  def latest_content
    agent_messages.where(message_type: 'assistant').last&.content
  end
end

# app/models/agent_message.rb
class AgentMessage < ApplicationRecord
  belongs_to :agent_session

  scope :assistants, -> { where(message_type: 'assistant') }
  scope :results, -> { where(message_type: 'result') }
end
```

## Background Job

Process agent queries in the background:

```ruby
# app/jobs/agent_job.rb
class AgentJob < ApplicationJob
  queue_as :agents
  sidekiq_options retry: 1  # Limit retries for expensive operations

  def perform(session_id, prompt, resume: false)
    session = AgentSession.find(session_id)
    session.update!(status: :running)

    options = build_options(session, resume)

    RubyLLM::AgentSDK.query(prompt, **options) do |message|
      process_message(session, message)
    end

    session.update!(status: :completed)
  rescue StandardError => e
    session.update!(status: :failed, metadata: session.metadata.merge(error: e.message))
    raise
  end

  private

  def build_options(session, resume)
    opts = {
      model: session.model_id || 'claude-sonnet-4-20250514',
      cwd: Rails.root.to_s,
      allowed_tools: %w[Read Glob Grep],
      permission_mode: :bypass_permissions,
      max_turns: 20,
      max_budget_usd: 1.0
    }

    opts[:resume] = session.claude_session_id if resume && session.claude_session_id
    opts
  end

  def process_message(session, message)
    # Save every message
    session.agent_messages.create!(
      message_type: message.type.to_s,
      subtype: message.subtype&.to_s,
      content: message.content,
      uuid: message.uuid,
      tool_calls: message.tool_calls,
      metadata: extract_metadata(message)
    )

    # Capture session ID
    if message.init?
      session.update!(claude_session_id: message.session_id)
    end

    # Update final stats
    if message.result?
      session.update!(
        total_cost_usd: message.total_cost_usd,
        num_turns: message.num_turns,
        result: message.content
      )
    end

    # Broadcast to Turbo Stream
    broadcast_message(session, message)
  end

  def extract_metadata(message)
    {
      model: message.respond_to?(:model) ? message.model : nil,
      usage: message.respond_to?(:usage) ? message.usage : nil
    }.compact
  end

  def broadcast_message(session, message)
    Turbo::StreamsChannel.broadcast_append_to(
      session,
      target: "agent_messages",
      partial: "agent_sessions/message",
      locals: { message: message, session: session }
    )
  end
end
```

## Controller

```ruby
# app/controllers/agent_sessions_controller.rb
class AgentSessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_session, only: [:show, :resume]

  def index
    @sessions = current_user.agent_sessions.recent
  end

  def show
    @messages = @session.agent_messages.order(:created_at)
  end

  def create
    @session = current_user.agent_sessions.create!(
      prompt: params[:prompt],
      model_id: params[:model_id] || 'claude-sonnet-4-20250514'
    )

    @session.run!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @session }
    end
  end

  def resume
    @session.resume!(params[:prompt])

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @session }
    end
  end

  private

  def set_session
    @session = current_user.agent_sessions.find(params[:id])
  end
end
```

## Views with Hotwire

### Show View

```erb
<!-- app/views/agent_sessions/show.html.erb -->
<%= turbo_stream_from @session %>

<div class="agent-session">
  <h1>Agent Session</h1>

  <div class="status-badge <%= @session.status %>">
    <%= @session.status.humanize %>
  </div>

  <div id="agent_messages" class="messages">
    <%= render @messages %>
  </div>

  <% if @session.completed? %>
    <%= form_with url: resume_agent_session_path(@session), method: :post do |f| %>
      <%= f.text_area :prompt, placeholder: "Continue the conversation..." %>
      <%= f.submit "Send" %>
    <% end %>
  <% elsif @session.running? %>
    <div class="typing-indicator">
      Agent is working...
    </div>
  <% end %>
</div>
```

### Message Partial

```erb
<!-- app/views/agent_sessions/_message.html.erb -->
<div class="message message-<%= message.type %>" id="<%= dom_id(message) rescue "msg-#{message.uuid}" %>">
  <div class="message-header">
    <span class="type"><%= message.type.to_s.humanize %></span>
    <% if message.respond_to?(:tool_name) && message.tool_name %>
      <span class="tool">Using: <%= message.tool_name %></span>
    <% end %>
  </div>

  <div class="message-content">
    <% if message.content.present? %>
      <%= simple_format(message.content) %>
    <% end %>
  </div>

  <% if message.result? %>
    <div class="message-stats">
      <span>Turns: <%= message.num_turns %></span>
      <span>Cost: $<%= message.total_cost_usd&.round(4) %></span>
    </div>
  <% end %>
</div>
```

### Turbo Stream Response

```erb
<!-- app/views/agent_sessions/create.turbo_stream.erb -->
<%= turbo_stream.append "sessions" do %>
  <%= render @session %>
<% end %>

<%= turbo_stream.replace "new_session_form" do %>
  <div class="alert alert-success">
    Agent started! <a href="<%= agent_session_path(@session) %>">View progress</a>
  </div>
<% end %>
```

## Stimulus Controller

For real-time updates:

```javascript
// app/javascript/controllers/agent_session_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messages", "input", "submit"]
  static values = { sessionId: Number }

  connect() {
    this.scrollToBottom()
  }

  messagesTargetConnected() {
    this.scrollToBottom()
  }

  scrollToBottom() {
    if (this.hasMessagesTarget) {
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    }
  }

  submit(event) {
    event.preventDefault()
    this.submitTarget.disabled = true
    this.inputTarget.disabled = true
  }
}
```

## Service Object Pattern

For complex agent interactions:

```ruby
# app/services/code_review_agent.rb
class CodeReviewAgent
  include ActiveModel::Model

  attr_accessor :user, :repository_path, :branch

  def call
    session = user.agent_sessions.create!(
      prompt: build_prompt,
      model_id: 'claude-sonnet-4-20250514',
      metadata: { type: 'code_review', branch: branch }
    )

    CodeReviewJob.perform_later(session.id, repository_path, branch)
    session
  end

  private

  def build_prompt
    <<~PROMPT
      Review the code changes in the #{branch} branch.

      Focus on:
      1. Security vulnerabilities
      2. Performance issues
      3. Code style and best practices
      4. Test coverage

      Provide specific line-by-line feedback.
    PROMPT
  end
end

# app/jobs/code_review_job.rb
class CodeReviewJob < ApplicationJob
  queue_as :agents

  def perform(session_id, repository_path, branch)
    session = AgentSession.find(session_id)
    session.update!(status: :running)

    hooks = build_audit_hooks(session)

    RubyLLM::AgentSDK.query(
      session.prompt,
      cwd: repository_path,
      allowed_tools: %w[Read Glob Grep Bash],
      permission_mode: :bypass_permissions,
      hooks: hooks,
      max_budget_usd: 2.0
    ) do |message|
      process_and_broadcast(session, message)
    end

    session.update!(status: :completed)
  rescue => e
    session.update!(status: :failed, metadata: session.metadata.merge(error: e.message))
    raise
  end

  private

  def build_audit_hooks(session)
    {
      pre_tool_use: [
        {
          handler: ->(ctx) {
            Rails.logger.info "[Agent #{session.id}] Tool: #{ctx.tool_name}"
            RubyLLM::AgentSDK::Hooks::Result.approve
          }
        }
      ]
    }
  end

  def process_and_broadcast(session, message)
    session.agent_messages.create!(
      message_type: message.type.to_s,
      content: message.content,
      uuid: message.uuid
    )

    Turbo::StreamsChannel.broadcast_append_to(
      session,
      target: "agent_messages",
      partial: "agent_sessions/message",
      locals: { message: message }
    )

    if message.result?
      session.update!(
        total_cost_usd: message.total_cost_usd,
        num_turns: message.num_turns,
        result: message.content
      )
    end
  end
end

# Usage in controller
class CodeReviewsController < ApplicationController
  def create
    agent = CodeReviewAgent.new(
      user: current_user,
      repository_path: params[:repository_path],
      branch: params[:branch]
    )

    @session = agent.call
    redirect_to agent_session_path(@session)
  end
end
```

## API Endpoint

For API-driven agents:

```ruby
# app/controllers/api/v1/agents_controller.rb
module Api
  module V1
    class AgentsController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_api_token!

      def create
        session = current_api_user.agent_sessions.create!(
          prompt: params[:prompt],
          model_id: params[:model] || 'claude-sonnet-4-20250514',
          metadata: { api: true }
        )

        if params[:sync]
          # Synchronous execution (blocks until complete)
          run_sync(session, params[:prompt])
          render json: { session: session.as_json, messages: session.agent_messages }
        else
          # Async execution
          session.run!
          render json: { session_id: session.id, status: 'running' }
        end
      end

      def show
        session = current_api_user.agent_sessions.find(params[:id])
        render json: {
          session: session.as_json,
          messages: session.agent_messages.order(:created_at)
        }
      end

      private

      def run_sync(session, prompt)
        session.update!(status: :running)

        RubyLLM::AgentSDK.query(
          prompt,
          cwd: Rails.root.to_s,
          allowed_tools: %w[Read Glob Grep],
          permission_mode: :bypass_permissions
        ) do |message|
          session.agent_messages.create!(
            message_type: message.type.to_s,
            content: message.content,
            uuid: message.uuid
          )

          if message.result?
            session.update!(
              status: :completed,
              total_cost_usd: message.total_cost_usd,
              num_turns: message.num_turns,
              result: message.content
            )
          end
        end
      end
    end
  end
end
```

## Testing

```ruby
# spec/jobs/agent_job_spec.rb
require 'rails_helper'

RSpec.describe AgentJob, type: :job do
  let(:user) { create(:user) }
  let(:session) { create(:agent_session, user: user) }

  it "processes agent query" do
    # Mock the CLI
    allow_any_instance_of(RubyLLM::AgentSDK::CLI).to receive(:stream).and_yield(
      '{"type":"system","subtype":"init","session_id":"test-123"}'
    ).and_yield(
      '{"type":"result","subtype":"success","content":"Done"}'
    )

    AgentJob.perform_now(session.id, "Test prompt")

    session.reload
    expect(session.status).to eq('completed')
    expect(session.claude_session_id).to eq('test-123')
  end
end
```

## Performance Tips

1. **Use Sidekiq** for background jobs - it handles concurrency well
2. **Set budget limits** to prevent runaway costs
3. **Monitor job queues** - agent jobs can be long-running
4. **Use connection pooling** appropriately
5. **Consider caching** for repeated queries

```ruby
# config/sidekiq.yml
:concurrency: 5
:queues:
  - [agents, 2]  # Lower priority, fewer workers
  - [default, 5]

# config/initializers/agent_sdk.rb
Rails.application.config.after_initialize do
  # Configure global defaults
  RubyLLM::AgentSDK::Hooks.logger = Rails.logger
end
```

## Next Steps

- [Hooks]({% link agent_sdk/hooks.md %}) - Add monitoring and validation
- [Permissions]({% link agent_sdk/permissions.md %}) - Control tool access
- [Examples]({% link agent_sdk/examples.md %}) - More implementation patterns
