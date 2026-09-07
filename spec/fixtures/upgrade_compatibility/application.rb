# frozen_string_literal: true

class UpgradeCompatibilityApplication
  include WebMock::API

  MODEL = 'gpt-4.1'
  OTHER_MODEL = 'gpt-4.1-mini'
  TWO_ONLY_MODEL = 'gpt-4.1-nano'

  def initialize(version:, directory:)
    @version = version
    @directory = directory
    ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: File.join(directory, 'compatibility.sqlite3'))
    ActiveRecord::Migration.verbose = false
    configure_library
    @catalog_models = [MODEL, OTHER_MODEL, TWO_ONLY_MODEL].to_h do |id|
      model = version == 'legacy' ? RubyLLM.models.find(id, :openai) : RubyLLM.models.find(id, provider: :openai)
      [id, model]
    end
    load_integration
    create_schema unless connection.table_exists?(:chats)
    define_models
    install_guard
    WebMock.enable!
    WebMock.disable_net_connect!
  end

  def seed(_arguments)
    editable = create_chat('editable')
    answer = ask(editable, 'legacy answer')
    raw = editable.add_message(role: :assistant, content: RubyLLM::Content::Raw.new({ 'answer' => 42 }))
    empty_raw = [{}, []].map do |value|
      message = editable.add_message(role: :assistant, content: 'text with empty raw content')
      message.update!(content_raw: value)
      { id: message.id, raw: value }
    end
    removable = editable.add_message(role: :user, content: 'remove this message')
    claimed = create_chat('claimed')
    ask(claimed, 'claimable answer')
    deleted = create_chat('deleted')
    ask(deleted, 'delete this conversation')
    tool_chat = create_chat('tools')
    tool_round(tool_chat, 'legacy-tool', 'legacy result')
    {
      version: RubyLLM::VERSION, editable: editable.id, answer: answer.id, raw: raw.id, empty_raw:,
      removable: removable.id, claimed: claimed.id, claimed_message: claimed.messages.first.id,
      deleted: deleted.id, tools: tool_chat.id, tool_message: tool_chat.messages.first.id,
      legacy_model: editable[:model_id],
      legacy_tool: ::ToolCall.find_by!(tool_call_id: 'legacy-tool').id
    }
  end

  def prepare(_arguments)
    migrate(Dir[File.join(@directory, 'db/migrate/*prepare*.rb')])
    { legacy_model_column: connection.column_exists?(:chats, :model_id),
      legacy_models: connection.table_exists?(:models), legacy_tools: connection.table_exists?(:tool_calls) }
  end

  def abort_prepare(_arguments)
    migration = load_migration(Dir[File.join(@directory, 'db/migrate/*prepare*.rb')].first)
    migration.define_singleton_method(:validate_upgrade) { raise 'Simulated interrupted preparation' }
    migration.migrate(:up)
  end

  def preparation_schema(_arguments)
    { state: connection.table_exists?(:ruby_llm_v2_upgrades), models: connection.table_exists?(:ruby_llm_models),
      tools: connection.table_exists?(:ruby_llm_tool_calls),
      version: connection.column_exists?(:chats, :ruby_llm_version),
      reference: connection.column_exists?(:chats, :ruby_llm_model_id) }
  end

  def migrate_all(_arguments)
    migrate(Dir[File.join(@directory, 'db/migrate/*.rb')])
    { status: 'migrated', required_model: required_model? }
  end

  def finish_migrations(_arguments)
    migrate(Dir[File.join(@directory, 'db/migrate/*{backfill,finish}*.rb')])
    { status: 'migrated', required_model: required_model? }
  end

  def cleanup(_arguments)
    migrate(Dir[File.join(@directory, 'db/migrate/*cleanup*.rb')])
    remaining = %i[models tool_calls].select { |table| connection.table_exists?(table) }
    { chats: %i[model_id ruby_llm_version], messages: %i[model_id tool_call_id content_raw input_tokens output_tokens] }
      .each do |table, columns|
        remaining.concat(columns.filter_map do |column|
          "#{table}.#{column}" if connection.column_exists?(table, column)
        end)
      end
    { remaining_legacy_schema: remaining }
  end

  def after_cleanup(arguments)
    chat = ::Chat.find(arguments.fetch('owned'))
    original_messages = snapshot_chat(chat).fetch(:messages)
    answer = ask(chat, 'saved after cleanup')
    new_answer = ask(create_chat('after cleanup'), 'new conversation after cleanup')
    { original_messages:, answer: answer.content, new_answer: new_answer.content, required_model: required_model? }
  end

  def snapshot(arguments)
    chats = arguments.fetch('ids').to_h do |id|
      chat = ::Chat.find_by(id:)
      [id.to_s, chat && snapshot_chat(chat)]
    end
    { version: RubyLLM::VERSION, visible_ids: ::Chat.order(:id).pluck(:id),
      visible_message_ids: ::Message.order(:id).pluck(:id), chats: }
  end

  def change_current(arguments)
    claimed = ::Chat.find(arguments.fetch('claimed'))
    claimed.to_llm
    read_ownership = claimed.reload[:ruby_llm_version]
    ask(claimed, 'written by version two')
    owned = create_chat('two only')
    register_model(TWO_ONLY_MODEL)
    owned.with_model(TWO_ONLY_MODEL, provider: :openai)
    tool_round(owned, 'two-only-tool', 'two only result')
    owned.add_message(role: :assistant, content: 'two only citation',
                      citations: [{ url: 'https://example.com/reference', title: 'Reference' }])
    approval_tool = ::ApprovalLookup.new
    owned.with_tools(approval_tool)
    approval = RubyLLM::ToolCall.new(id: 'awaiting-approval', name: approval_tool.name, arguments: {})
    owned.add_message(role: :assistant, content: nil, tool_calls: { approval.id => approval })
    raise 'The fixture did not create a pending approval' unless owned.awaiting_approval?

    { owned: owned.id, claimed: claimed.id, read_ownership:, owned_snapshot: snapshot_chat(owned),
      pending_approval_ids: owned.pending_approvals.map(&:tool_call_id),
      owned_model: owned[:ruby_llm_model_id],
      owned_tool: RubyLLM::ActiveRecord::ToolCall.find_by!(tool_call_id: 'two-only-tool').id }
  end

  def change_legacy(arguments)
    register_model(OTHER_MODEL)
    chat = ::Chat.find(arguments.fetch('editable'))
    chat.with_model(OTHER_MODEL, provider: :openai)
    chat.with_instructions('updated while on version one')
    answer = ask(chat, 'new legacy answer')
    raw = ::Message.find(arguments.fetch('raw'))
    raw.update!(content: 'edited legacy text', content_raw: nil)
    ::Message.find(arguments.fetch('removable')).destroy!
    ::Chat.find(arguments.fetch('deleted')).destroy!
    tool_chat = ::Chat.find(arguments.fetch('tools'))
    while ::ToolCall.maximum(:id).to_i + 1 < arguments.fetch('collision_tool', 0)
      tool_round(tool_chat, "legacy-extra-#{::ToolCall.maximum(:id)}", 'another legacy result')
    end
    tool_round(tool_chat, 'returned-legacy-tool', 'new legacy result')
    new_chat = create_chat('new legacy conversation')
    ask(new_chat, 'created after rollback')
    { new_chat: new_chat.id, answer: answer.id, returned_model: chat[:model_id],
      returned_tool: ::ToolCall.find_by!(tool_call_id: 'returned-legacy-tool').id,
      snapshot: snapshot_chat(chat) }
  end

  def transition(arguments)
    RubyLLM::Generators::UpgradeMigration.new.public_send(arguments.fetch('action'))
    { transitioned: arguments.fetch('action') }
  end

  def resolve_approval(arguments)
    chat = ::Chat.find(arguments.fetch('owned')).with_tools(::ApprovalLookup)
    chat.deny('awaiting-approval')
    chat.run_tools
    raise 'The denied approval did not receive a result' if chat.awaiting_approval?

    { owned_snapshot: snapshot_chat(chat) }
  end

  def watch_stale(arguments)
    chat = ::Chat.find(arguments.fetch('chat'))
    message = ::Message.find(arguments.fetch('message'))
    tool_call = ::ToolCall.find(arguments.fetch('tool_call'))
    $stdout.write("#{JSON.generate(ready: true)}\n")
    $stdout.flush
    $stdin.gets
    errors = [-> { chat.update!(title: 'forbidden') }, -> { chat.destroy! },
              -> { message.update!(content: 'forbidden') }, -> { message.destroy! },
              -> { tool_call.update!(name: 'forbidden') }, -> { tool_call.destroy! },
              -> { chat.add_message(role: :user, content: 'forbidden') },
              -> { chat.reload }, -> { chat.to_llm }, -> { message.reload }, -> { message.to_llm },
              -> { tool_call.reload }].map do |action|
      action.call
      nil
    rescue StandardError => e
      { class: e.class.name, message: e.message }
    end
    { errors: }
  end

  def check_current_cache(arguments)
    chat = ::Chat.find(arguments.fetch('chat'))
    chat.to_llm
    RubyLLM::Generators::UpgradeMigration.new.rollback
    errors = [-> { chat.compact }, -> { chat.run_tools }, -> { chat.count_tokens },
              -> { chat.ask_later('This must not create a batch') }].map do |action|
      action.call
      nil
    rescue StandardError => e
      { class: e.class.name, message: e.message }
    end
    { errors:, requests: WebMock::RequestRegistry.instance.requested_signatures.hash.values.sum,
      batches: RubyLLM::ActiveRecord::Batch.count }
  end

  private

  def connection
    ActiveRecord::Base.connection
  end

  def required_model?
    !connection.columns(:chats).find { |column| column.name == 'ruby_llm_model_id' }.null
  end

  def register_model(id)
    model = @version == 'legacy' ? ::Model : RubyLLM::ActiveRecord::Model
    model.from_llm(@catalog_models.fetch(id)).save!
  end

  def configure_library
    RubyLLM.configure do |config|
      config.openai_api_key = 'test'
      config.default_model = MODEL
      config.log_level = :fatal
      if @version == 'legacy'
        config.use_new_acts_as = true
      else
        config.openai_protocol = :chat_completions
        config.model_registry_file = nil
      end
    end
  end

  def load_integration
    names = if @version == 'legacy'
              %w[payload_helpers chat_methods message_methods model_methods tool_call_methods acts_as]
            else
              %w[payload_helpers model tool_call usage batch chat_methods message_methods acts_as]
            end
    names.each { |name| require "ruby_llm/active_record/#{name}" }
    require 'generators/ruby_llm/upgrade/upgrade_migration' if @version == 'current'
    ActiveRecord::Base.include RubyLLM::ActiveRecord::ActsAs
  end

  def define_models
    Object.const_set(:Model, Class.new(ActiveRecord::Base))
    Object.const_set(:Chat, Class.new(ActiveRecord::Base))
    Object.const_set(:Message, Class.new(ActiveRecord::Base))
    Object.const_set(:ToolCall, Class.new(ActiveRecord::Base))
    ::Model.acts_as_model if @version == 'legacy'
    ::Chat.acts_as_chat
    ::Message.acts_as_message
    ::ToolCall.acts_as_tool_call if @version == 'legacy'
    return if @version == 'legacy'

    Object.const_set(:ApprovalLookup, Class.new(RubyLLM::Tool))
    ::ApprovalLookup.description('A tool that needs approval')
    ::ApprovalLookup.requires_approval
    ::ApprovalLookup.define_method(:execute) { raise 'The approval-only fixture tool was executed' }
  end

  def install_guard
    path = File.join(@directory, 'app/models/concerns/ruby_llm_upgrade.rb')
    return unless File.exist?(path)

    load path
    tool_class = @version == 'legacy' ? ::ToolCall : RubyLLM::ActiveRecord::ToolCall
    RubyLLMUpgrade.install(chat: ::Chat, message: ::Message, tool_call: tool_class)
  end

  def migrate(paths)
    paths.each { |path| load_migration(path).migrate(:up) }
  end

  def load_migration(path)
    name = File.read(path).match(/class (\w+) < ActiveRecord::Migration/)[1]
    load path
    Object.const_get(name).new
  end

  def create_chat(title)
    ::Chat.create!(title:, model: MODEL, provider: :openai)
  end

  def ask(chat, text)
    stub_request(:post, 'https://api.openai.com/v1/chat/completions').to_return(
      status: 200, headers: { 'Content-Type' => 'application/json' },
      body: JSON.generate(id: "response-#{text}", model: chat.model_id,
                          choices: [{ message: { role: 'assistant', content: text }, finish_reason: 'stop' }],
                          usage: { prompt_tokens: 12, completion_tokens: 3, total_tokens: 15 })
    )
    chat.ask('A local compatibility question')
    chat.messages.order(:id).last
  end

  def tool_round(chat, id, content)
    calls = { id => RubyLLM::ToolCall.new(id:, name: 'lookup', arguments: { query: 'Ruby' }) }
    chat.add_message(role: :assistant, content: nil, tool_calls: calls)
    chat.add_message(role: :tool, content:, tool_call_id: id)
    ask(chat, "completed #{id}")
  end

  def snapshot_chat(chat)
    messages = chat.messages.order(:id).map do |record|
      message = record.to_llm
      content = message.content
      content = content.value if content.respond_to?(:value)
      { id: record.id, role: message.role, content:, raw: record.attributes['raw_content'],
        tool_calls: message.tool_calls&.keys, tool_call_id: message.tool_call_id,
        tokens: message.tokens&.to_h, citations: message.respond_to?(:citations) ? message.citations.map(&:to_h) : [] }
    end
    { id: chat.id, title: chat.title, model: chat.model_id, provider: chat.provider, messages:,
      ownership: chat.attributes['ruby_llm_version'], usage: usage_snapshot(chat),
      protected_rows: protected_rows(chat) }
  end

  def protected_rows(chat)
    return unless @version == 'current' && chat.attributes['ruby_llm_version'] == 2

    { usages: chat.ruby_llm_usages.order(:id).pluck(:id),
      tools: RubyLLM::ActiveRecord::ToolCall.where(message: chat.messages).order(:id)
                                            .pluck(:id, :tool_call_id, :result_id, :approval) }
  end

  def usage_snapshot(chat)
    return [] if @version == 'legacy'

    chat.ruby_llm_usages.order(:id).map do |entry|
      entry.attributes.slice('message_id', 'model', 'input_tokens', 'output_tokens', 'status')
    end
  end

  def create_schema
    load File.join(__dir__, 'schema.rb')
  end
end
