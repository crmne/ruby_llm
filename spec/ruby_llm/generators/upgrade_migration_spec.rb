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
  let(:legacy_home) { ENV.fetch('RUBY_LLM_LEGACY_GEM_HOME', nil) }
  let(:gem_paths) do
    ([legacy_home] + Gem.path + Gem.loaded_specs.values.map(&:base_dir)).compact.uniq.join(File::PATH_SEPARATOR)
  end
  let(:directory) { Dir.mktmpdir('ruby_llm_copy_upgrade') }

  around do |example|
    example.run
  ensure
    FileUtils.remove_entry(directory)
  end

  it 'round trips real 1.16 writes while preserving two-owned conversations and reconciling deletions' do
    seed = run_stage('legacy', 'seed')
    expect(seed.fetch('version')).to eq('1.16.0')
    generate_copy_upgrade
    legacy = run_stage('legacy', 'snapshot', ids: [seed.fetch('editable')])
    expect(legacy.dig('chats', seed.fetch('editable').to_s, 'messages'))
      .to include(a_hash_including('content' => { 'answer' => 42 }))
    expect(run_stage('current', 'prepare').values).to all(be(true))
    expect_stage_failure('legacy', 'snapshot', ids: [seed.fetch('editable')], message: /preparing/)
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
    allow(generator).to receive_messages(postgresql?: false, mysql?: false, migration_version: '[8.1]')
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
              'RUBY_LLM_COMPATIBILITY_GEMS' => dependencies)
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
