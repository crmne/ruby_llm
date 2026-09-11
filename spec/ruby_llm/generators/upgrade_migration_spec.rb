# frozen_string_literal: true

require 'spec_helper'
require 'generators/ruby_llm/upgrade/upgrade_generator'
require 'generators/ruby_llm/upgrade/upgrade_migration'
require 'open3'
require 'tmpdir'
require 'rbconfig'

RSpec.describe RubyLLM::Generators::UpgradeMigration, :generator do
  let(:repository) { File.expand_path('../../..', __dir__) }
  let(:runner) { File.join(repository, 'spec/fixtures/upgrade_compatibility/runner.rb') }
  let(:gem_paths) do
    ([legacy_home] + Gem.path + Gem.loaded_specs.values.map(&:base_dir)).compact.uniq.join(File::PATH_SEPARATOR)
  end
  let(:directory) { Dir.mktmpdir('ruby_llm_copy_upgrade') }
  let(:database_configuration) do
    next nil unless database_url

    ActiveRecord::Base.establish_connection(database_url)
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    name = "ruby_llm_compatibility_#{Process.pid}_#{SecureRandom.hex(4)}"
    if config[:adapter] == 'postgresql'
      ActiveRecord::Base.connection.execute("CREATE SCHEMA #{ActiveRecord::Base.connection.quote_table_name(name)}")
      config.merge(schema_search_path: name)
    else
      ActiveRecord::Base.connection.create_database(name, charset: 'utf8mb4')
      config.merge(database: name)
    end
  end

  def legacy_home = ENV.fetch('RUBY_LLM_LEGACY_GEM_HOME', nil)
  def database_url = ENV.fetch('RUBY_LLM_COMPATIBILITY_URL', nil)

  around do |example|
    example.run
  ensure
    if database_configuration
      ActiveRecord::Base.establish_connection(database_url)
      if database_configuration[:adapter] == 'postgresql'
        schema = ActiveRecord::Base.connection.quote_table_name(database_configuration.fetch(:schema_search_path))
        ActiveRecord::Base.connection.execute("DROP SCHEMA #{schema} CASCADE")
      else
        ActiveRecord::Base.connection.drop_database(database_configuration.fetch(:database))
      end
      ActiveRecord::Base.remove_connection
    end
    FileUtils.remove_entry(directory)
  end

  it 'keeps a warm 1.16 process writing through prepare and repeated backfill, then fences it at finish' do
    seed = run_stage('legacy', 'seed')
    generate_copy_upgrade
    arguments = { chat: seed.fetch('editable'), raw: seed.fetch('raw') }
    Open3.popen3(child_environment, *command('legacy', 'watch_online', arguments)) do |input, output, errors, waiter|
      expect(JSON.parse(output.gets)).to eq('ready' => true)
      run_stage('current', 'prepare')
      input.puts('after prepare')
      expect(JSON.parse(output.gets)).to include('content' => 'after prepare', 'raw' => nil)
      run_stage('current', 'backfill')
      input.puts('after backfill')
      response = JSON.parse(output.gets)
      expect(response).to include('content' => 'after backfill', 'raw' => nil)
      run_stage('current', 'backfill')
      input.puts('before finish')
      expect(JSON.parse(output.gets)).to include('content' => 'before finish')
      run_stage('current', 'finish')
      input.puts('too late')
      expect(JSON.parse(output.gets)).to include('error' => 'ActiveRecord::ReadOnlyRecord')
      input.puts('stop')
      input.close
      expect(waiter.value.success?).to be(true), errors.read
      snapshot = run_stage('current', 'snapshot', ids: [seed.fetch('editable')])
      messages = snapshot.dig('chats', seed.fetch('editable').to_s, 'messages')
      expect(messages).to include(a_hash_including('content' => 'before finish'))
      expect(messages.map { |message| message.fetch('content') }).not_to include('too late')
    end
  end

  it 'round trips real 1.16 writes while preserving two-owned conversations and reconciling deletions' do
    seed = run_stage('legacy', 'seed')
    expect(seed.fetch('version')).to eq('1.16.0')
    generate_copy_upgrade
    legacy = run_stage('legacy', 'snapshot', ids: [seed.fetch('editable')])
    expect(legacy.dig('chats', seed.fetch('editable').to_s, 'messages'))
      .to include(a_hash_including('content' => { 'answer' => 42 }))
    expect(run_stage('current', 'prepare').values).to all(be(true))
    prepared = run_stage('legacy', 'snapshot', ids: [seed.fetch('editable')])
    expect(prepared.dig('chats', seed.fetch('editable').to_s, 'messages'))
      .to eq(legacy.dig('chats', seed.fetch('editable').to_s, 'messages'))
    expect(run_stage('current', 'migrate_all').fetch('required_model')).to be(true)
    changed = run_stage('current', 'change_current', claimed: seed.fetch('claimed'))
    expect(changed.fetch('read_ownership')).to eq(1)
    expect(changed.fetch('pending_approval_ids')).to eq(['awaiting-approval'])
    expect_stage_failure('current', 'transition', action: 'rollback', message: /pending tool calls and approvals/)
    changed.merge!(run_stage('current', 'resolve_approval', owned: changed.fetch('owned')))
    run_stage('current', 'transition', action: 'rollback')
    reverted = run_stage('legacy', 'snapshot', ids: [changed.fetch('owned'), seed.fetch('claimed')])
    expect(reverted.fetch('chats').values).to all(be_nil)
    expect(reverted.fetch('visible_ids')).to include(seed.fetch('editable'), seed.fetch('tools'))
    owned_messages = changed.fetch('owned_snapshot').fetch('messages').map { |message| message.fetch('id') }
    expect(reverted.fetch('visible_message_ids') & owned_messages).to be_empty
    returned = run_stage('legacy', 'change_legacy', seed.merge('collision_tool' => changed.fetch('owned_tool')))
    expect(returned.fetch('returned_model')).to eq(changed.fetch('owned_model'))
    expect(returned.fetch('returned_tool')).to eq(changed.fetch('owned_tool'))
    run_stage('current', 'transition', action: 'resume')
    ids = [seed.fetch('editable'), seed.fetch('tools'), seed.fetch('deleted'), changed.fetch('owned'),
           returned.fetch('new_chat')]
    restored = run_stage('current', 'snapshot', ids:)
    verify_resumed_records(restored, seed, changed, returned)
    run_stage('current', 'transition', action: 'rollback')
    run_stage('current', 'transition', action: 'resume')
    expect(run_stage('current', 'snapshot', ids:)).to eq(restored)
  end

  it 'preserves 1.16 raw-content precedence without replacing text with empty raw values' do
    seed = run_stage('legacy', 'seed')
    generate_copy_upgrade
    run_stage('current', 'migrate_all')
    snapshot = run_stage('current', 'snapshot', ids: [seed.fetch('editable')])
    messages = snapshot.dig('chats', seed.fetch('editable').to_s, 'messages')
    structured = messages.find { |message| message.fetch('id') == seed.fetch('raw') }
    expect(JSON.parse(structured.fetch('content'))).to eq('answer' => 42)
    seed.fetch('empty_raw').each do |message|
      expect(messages).to include(a_hash_including(message.merge('content' => 'text with empty raw content')))
    end
  end

  it 'rejects a delayed 1.16 provider response after finish and rollback' do
    seed = run_stage('legacy', 'seed')
    generate_copy_upgrade
    run_stage('current', 'prepare')
    run_stage('current', 'backfill')
    arguments = { chat: seed.fetch('editable') }
    Open3.popen3(child_environment, *command('legacy', 'watch_response', arguments)) do |input, output, errors, waiter|
      expect(JSON.parse(output.gets)).to eq('ready' => true)
      run_stage('current', 'finish')
      run_stage('current', 'transition', action: 'rollback')
      input.puts('continue')
      input.close
      expect(JSON.parse(output.read)).to eq('error' => 'ActiveRecord::ReadOnlyRecord')
      expect(waiter.value.success?).to be(true), errors.read
    end
    snapshot = run_stage('legacy', 'snapshot', ids: [seed.fetch('editable')])
    messages = snapshot.dig('chats', seed.fetch('editable').to_s, 'messages')
    expect(messages.map { |message| message.fetch('content') }).not_to include('late response')
  end

  it 'does not restore a legacy tool conversation deleted by two after rollback and resume' do
    seed = run_stage('legacy', 'seed')
    generate_copy_upgrade
    run_stage('current', 'migrate_all')
    run_stage('current', 'delete_current', chat: seed.fetch('tools'))
    run_stage('current', 'transition', action: 'rollback')
    run_stage('current', 'transition', action: 'resume')
    snapshot = run_stage('current', 'snapshot', ids: [seed.fetch('tools')])
    expect(snapshot.fetch('chats').fetch(seed.fetch('tools').to_s)).to be_nil
  end

  it 'rejects downgraded saves and destroys through records loaded before two claimed their chat' do
    seed = run_stage('legacy', 'seed')
    generate_copy_upgrade
    arguments = { chat: seed.fetch('tools'), message: seed.fetch('tool_message'),
                  tool_call: seed.fetch('legacy_tool') }
    with_stale_legacy_records(arguments) do |input, output, errors, waiter|
      expect(JSON.parse(output.gets)).to eq('ready' => true)
      run_stage('current', 'prepare')
      run_stage('current', 'migrate_all')
      changed = run_stage('current', 'change_current', claimed: seed.fetch('tools'))
      run_stage('current', 'resolve_approval', owned: changed.fetch('owned'))
      run_stage('current', 'transition', action: 'rollback')
      input.puts('continue')
      input.close
      response = JSON.parse(output.read)
      expect(waiter.value.success?).to be(true), errors.read
      expect(response.fetch('errors').size).to eq(12)
      expect(response.fetch('errors')).to all(include('class' => 'ActiveRecord::ReadOnlyRecord',
                                                      'message' => 'This conversation contains RubyLLM 2.0 changes'))
      run_stage('current', 'transition', action: 'resume')
      restored = run_stage('current', 'snapshot', ids: [seed.fetch('tools')])
      chat = restored.fetch('chats').fetch(seed.fetch('tools').to_s)
      expect(chat.fetch('title')).to eq('tools')
      expect(chat.fetch('messages').map { |message| message.fetch('content') }).not_to include('forbidden')
      expect(chat.fetch('messages').map { |message| message.fetch('id') }).to include(seed.fetch('tool_message'))
    end
  end

  it 'finalizes and cleans legacy data before continuing without the compatibility concern' do
    seed = run_stage('legacy', 'seed')
    generate_copy_upgrade
    expect(run_stage('current', 'migrate_all').fetch('required_model')).to be(true)
    changed = run_stage('current', 'change_current', claimed: seed.fetch('claimed'))
    changed.merge!(run_stage('current', 'resolve_approval', owned: changed.fetch('owned')))
    generate_copy_upgrade(phase: 'cleanup')
    expect_stage_failure('current', 'cleanup', message: /finalize/)
    run_stage('current', 'transition', action: 'finalize')
    expect_stage_failure('current', 'transition', action: 'rollback', message: /must be active/)
    expect(run_stage('current', 'cleanup').fetch('remaining_legacy_schema')).to be_empty
    %w[app/models/concerns/ruby_llm_upgrade.rb config/initializers/ruby_llm_upgrade.rb].each do |path|
      FileUtils.rm(File.join(directory, path))
    end
    restored = run_stage('current', 'after_cleanup', owned: changed.fetch('owned'))
    expect(restored.fetch('original_messages')).to eq(changed.fetch('owned_snapshot').fetch('messages'))
    expect(restored.fetch('answer')).to eq('saved after cleanup')
    expect(restored.fetch('new_answer')).to eq('new conversation after cleanup')
    expect(restored.fetch('required_model')).to be(true)
  end

  it 'catches up legacy writes after rolling back an unfinished preparation' do
    seed = run_stage('legacy', 'seed')
    generate_copy_upgrade
    run_stage('current', 'prepare')
    run_stage('current', 'transition', action: 'rollback')
    returned = run_stage('legacy', 'change_legacy', seed)
    expect_stage_failure('current', 'transition', action: 'resume', message: /Finish the initial copy migrations/)
    expect(run_stage('current', 'finish_migrations').fetch('required_model')).to be(true)
    snapshot = run_stage('current', 'snapshot', ids: [seed.fetch('editable'), seed.fetch('deleted'),
                                                      returned.fetch('new_chat')])
    expect(snapshot.fetch('chats').fetch(seed.fetch('deleted').to_s)).to be_nil
    expect(snapshot.fetch('chats').fetch(returned.fetch('new_chat').to_s).fetch('title'))
      .to eq('new legacy conversation')
    expect(snapshot.fetch('chats').fetch(seed.fetch('editable').to_s).fetch('messages'))
      .to include(a_hash_including('id' => seed.fetch('raw'), 'content' => 'edited legacy text', 'raw' => nil))
  end

  it 'allows legacy writes when preparation stopped before creating the copied tables and columns' do
    seed = run_stage('legacy', 'seed')
    generate_copy_upgrade
    expect_stage_failure('current', 'abort_prepare', message: /Simulated interrupted preparation/)
    expect(run_stage('current', 'preparation_schema'))
      .to eq('state' => true, 'models' => false, 'tools' => false, 'version' => false, 'reference' => false)
    run_stage('current', 'transition', action: 'rollback')
    expect(run_stage('legacy', 'snapshot', ids: [seed.fetch('editable')]).fetch('visible_ids'))
      .to include(seed.fetch('editable'))
    returned = run_stage('legacy', 'change_legacy', seed)
    expect(run_stage('current', 'migrate_all').fetch('required_model')).to be(true)
    restored = run_stage('current', 'snapshot', ids: [returned.fetch('new_chat'), seed.fetch('tools')])
    expect(restored.fetch('chats').fetch(returned.fetch('new_chat').to_s).fetch('messages'))
      .to include(a_hash_including('content' => 'created after rollback'))
    expect(restored.fetch('chats').fetch(seed.fetch('tools').to_s).fetch('messages'))
      .to include(a_hash_including('tool_call_id' => 'returned-legacy-tool', 'content' => 'new legacy result'))
  end

  it 'blocks cached two API calls after switching the database back to one' do
    seed = run_stage('legacy', 'seed')
    generate_copy_upgrade
    run_stage('current', 'migrate_all')
    attempted = run_stage('current', 'check_current_cache', chat: seed.fetch('tools'))
    expect(attempted.fetch('errors').size).to eq(4)
    expect(attempted.fetch('errors')).to all(include('class' => 'ActiveRecord::ReadOnlyRecord',
                                                     'message' => 'RubyLLM 2 cannot access conversations while the ' \
                                                                  'copy upgrade is active on 1'))
    expect(attempted.fetch('requests')).to eq(0)
    expect(attempted.fetch('batches')).to eq(0)
  end

  def generate_copy_upgrade(**options)
    generator = RubyLLM::Generators::UpgradeGenerator.new([], { mode: 'copy', **options }, destination_root: directory)
    adapter = database_configuration&.fetch(:adapter)
    allow(generator).to receive_messages(postgresql?: adapter == 'postgresql', mysql?: adapter == 'mysql2',
                                         migration_version: '[8.1]')
    allow(generator).to receive(:say)
    allow(generator).to receive(:say_status)
    generator.invoke_all
    expect(File).to exist(File.join(directory, 'app/models/concerns/ruby_llm_upgrade.rb'))
  end

  def run_stage(version, stage, arguments = {})
    output, errors, status = Open3.capture3(child_environment, *command(version, stage, arguments))
    expect(status.success?).to be(true), "#{version} #{stage}: #{errors}\n#{output}"
    JSON.parse(output.lines.last)
  end

  def expect_stage_failure(version, stage, message:, **arguments)
    output, errors, status = Open3.capture3(child_environment, *command(version, stage, arguments))
    expect(status.success?).to be(false), "#{version} #{stage} unexpectedly succeeded: #{output}"
    expect(errors).to match(message)
  end

  def with_stale_legacy_records(arguments, &)
    Open3.popen3(child_environment, *command('legacy', 'watch_stale', arguments), &)
  end

  def command(version, stage, arguments)
    [RbConfig.ruby, runner, version, repository, directory, stage, JSON.generate(arguments)]
  end

  def child_environment
    dependencies = %w[json activerecord sqlite3 webmock].map do |name|
      "#{name}:#{Gem.loaded_specs.fetch(name).version}"
    end.join(',')
    ENV.keys.grep(/\ABUNDLE/).to_h { |name| [name, nil] }
       .merge('RUBYOPT' => nil, 'RUBYLIB' => nil, 'GEM_PATH' => gem_paths,
              'RUBY_LLM_COMPATIBILITY_GEMS' => dependencies,
              'RUBY_LLM_COMPATIBILITY_DATABASE' => database_configuration&.to_json)
  end

  def verify_resumed_records(restored, seed, changed, returned)
    chats = restored.fetch('chats')
    expect(chats.fetch(seed.fetch('deleted').to_s)).to be_nil
    expect(chats.fetch(changed.fetch('owned').to_s)).to eq(changed.fetch('owned_snapshot'))
    expect(chats.fetch(returned.fetch('new_chat').to_s).fetch('title')).to eq('new legacy conversation')
    editable = chats.fetch(seed.fetch('editable').to_s)
    expect(editable.fetch('model')).to eq('gpt-4.1-mini')
    expect(editable.fetch('provider')).to eq('openai')
    expect(editable.fetch('messages')).to include(a_hash_including('id' => seed.fetch('raw'),
                                                                   'content' => 'edited legacy text', 'raw' => nil))
    seed.fetch('empty_raw').each do |message|
      expect(editable.fetch('messages'))
        .to include(a_hash_including(message.merge('content' => 'text with empty raw content')))
    end
    expect(editable.fetch('messages').map { |message| message.fetch('id') }).not_to include(seed.fetch('removable'))
    expect(editable.fetch('usage').count { |entry| entry['message_id'] == returned.fetch('answer') }).to eq(1)
    tools = chats.fetch(seed.fetch('tools').to_s).fetch('messages')
    expect(tools).to include(a_hash_including('tool_call_id' => 'legacy-tool', 'content' => 'legacy result'),
                             a_hash_including('tool_call_id' => 'returned-legacy-tool',
                                              'content' => 'new legacy result'))
  end
end
