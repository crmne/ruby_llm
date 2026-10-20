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

  it 'is the base of MCP tasks' do
    expect(RubyLLM::MCP::Task.new(nil, { 'taskId' => 'task-1', 'status' => 'input_required' }))
      .to be_a(described_class).and be_input_required
  end
end
