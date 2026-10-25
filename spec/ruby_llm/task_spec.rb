# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Task do
  it 'loads the task it saved' do
    task = described_class.new(status: :input_required, status_message: 'Waiting for approval',
                               poll_interval: 5, data: { run_id: 7 })

    loaded = described_class.load(JSON.parse(task.to_h.to_json))

    expect(loaded).to have_attributes(status: :input_required, status_message: 'Waiting for approval',
                                      poll_interval: 5, data: { 'run_id' => 7 })
  end

  it 'keeps its own copy of its data, with String keys all the way down' do
    data = { run: { id: 7, steps: [{ name: :deploy }] } }

    task = described_class.new(data:)
    data[:run][:id] = 8

    expect(task.data).to eq('run' => { 'id' => 7, 'steps' => [{ 'name' => 'deploy' }] })
    expect(described_class.load(task.to_h).data).to eq(JSON.parse(task.to_h.to_json)['task']['data'])
  end

  it 'works until it says otherwise' do
    task = described_class.new

    expect(task).to have_attributes(status: :working, data: {})
    expect(task).not_to be_done
    expect(task).not_to be_input_required
    expect(task.to_h).to eq('task' => { 'status' => 'working' })
  end

  it 'is done once it completed, failed, or was cancelled' do
    expect(%i[completed failed cancelled].map { |status| described_class.new(status:) }).to all(be_done)
  end

  it 'refuses a status it does not know' do
    expect { described_class.new(status: :complete) }.to raise_error(ArgumentError, /Unknown task status: :complete/)
  end

  it 'is the base of MCP tasks' do
    expect(RubyLLM::MCP::Task.new(nil, { 'taskId' => 'task-1', 'status' => 'input_required' }))
      .to be_a(described_class).and be_input_required
  end
end
