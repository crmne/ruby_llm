# frozen_string_literal: true

require 'spec_helper'

class WorkflowCaptureInstrumenter
  attr_reader :events

  def initialize
    @events = []
  end

  def instrument(name, payload)
    result = block_given? ? yield : nil
    events << [name, payload.dup]
    result
  end
end

RSpec.describe RubyLLM::Workflow do
  include_context 'with configured RubyLLM'

  let(:instrumenter) { WorkflowCaptureInstrumenter.new }
  let(:context) { RubyLLM.context { |config| config.instrumenter = instrumenter } }

  it 'adds workflow and step identity to every nested instrumentation event' do
    result = context.workflow('Write article', id: 'article-42') do |workflow|
      workflow.step('Research', id: 'research-1') do
        RubyLLM::Instrumentation.instrument('example.ruby_llm', config: context.config) { :notes }
      end
    end

    expect(result).to eq(:notes)
    expect(event_payload('example.ruby_llm')).to include(
      workflow_id: 'article-42',
      workflow_name: 'Write article',
      workflow_step_id: 'research-1',
      workflow_step_name: 'Research'
    )
    expect(event_payload('workflow_step.ruby_llm')).to include(
      workflow_id: 'article-42',
      workflow_name: 'Write article',
      workflow_step_id: 'research-1',
      workflow_step_name: 'Research'
    )
    expect(event_payload('workflow.ruby_llm')).to include(
      workflow_id: 'article-42',
      workflow_name: 'Write article'
    )
    expect(event_payload('workflow.ruby_llm')).not_to have_key(:workflow_step_id)
    expect(event_payload('workflow.ruby_llm')).not_to have_key(:workflow_metadata)
  end

  it 'attaches workflow metadata as workflow_metadata alongside per-call metadata' do
    context.workflow('With metadata', id: 'meta-1', metadata: { account_id: 7 }) do |workflow|
      workflow.step('Only step') do
        RubyLLM::Instrumentation.instrument('example.ruby_llm', metadata: { request: 'r-1' }, config: context.config)
      end
    end

    payload = event_payload('example.ruby_llm')
    expect(payload[:workflow_metadata]).to eq(account_id: 7)
    expect(payload[:metadata]).to eq(request: 'r-1')
    expect(event_payload('workflow.ruby_llm')[:workflow_metadata]).to eq(account_id: 7)
    expect(event_payload('workflow_step.ruby_llm')[:workflow_metadata]).to eq(account_id: 7)
  end

  it 'generates IDs when they are omitted' do
    workflow_id = nil

    context.workflow('Generated IDs') do |workflow|
      workflow_id = workflow.id
      workflow.step('First') { :ok }
    end

    expect(workflow_id).to match(/\A[0-9a-f-]{36}\z/)
    expect(event_payload('workflow_step.ruby_llm')[:workflow_step_id]).to match(/\A[0-9a-f-]{36}\z/)
  end

  it 'records parent identity for nested steps' do
    context.workflow('Nested', id: 'nested-1') do |workflow|
      workflow.step('Outer', id: 'outer-1') do
        workflow.step('Inner', id: 'inner-1') { :ok }
      end
    end

    inner = instrumenter.events
                        .filter_map { |name, payload| payload if name == 'workflow_step.ruby_llm' }
                        .find { |payload| payload[:workflow_step_id] == 'inner-1' }
    outer = instrumenter.events
                        .filter_map { |name, payload| payload if name == 'workflow_step.ruby_llm' }
                        .find { |payload| payload[:workflow_step_id] == 'outer-1' }

    expect(inner[:workflow_step_parent_id]).to eq('outer-1')
    expect(outer).not_to have_key(:workflow_step_parent_id)
  end

  it 'links nested workflows to their parent workflow and step' do
    context.workflow('Outer', id: 'outer-wf') do |outer|
      outer.step('Compose', id: 'compose-1') do
        context.workflow('Inner', id: 'inner-wf') do |inner|
          inner.step('Summarize', id: 'inner-step-1') do
            RubyLLM::Instrumentation.instrument('example.ruby_llm', config: context.config)
          end
        end
        RubyLLM::Instrumentation.instrument('resumed.ruby_llm', config: context.config)
      end
    end

    inner_workflow = workflow_event('inner-wf')
    expect(inner_workflow).to include(workflow_parent_id: 'outer-wf', workflow_parent_step_id: 'compose-1')
    expect(event_payload('example.ruby_llm')).to include(
      workflow_id: 'inner-wf',
      workflow_step_id: 'inner-step-1',
      workflow_parent_id: 'outer-wf'
    )
    expect(workflow_event('outer-wf')).not_to have_key(:workflow_parent_id)
    expect(event_payload('resumed.ruby_llm')).to include(workflow_id: 'outer-wf', workflow_step_id: 'compose-1')
    expect(event_payload('resumed.ruby_llm')).not_to have_key(:workflow_parent_id)
  end

  it 'restores the previous instrumentation context after errors' do
    expect do
      context.workflow('Failing', id: 'failing-1') do |workflow|
        workflow.step('Explode') { raise 'boom' }
      end
    end.to raise_error(RuntimeError, 'boom')

    RubyLLM::Instrumentation.instrument('after.ruby_llm', config: context.config)

    expect(event_payload('after.ruby_llm')).not_to have_key(:workflow_id)
  end

  it 'rejects empty names and missing blocks' do
    expect { context.workflow('') { :ok } }.to raise_error(ArgumentError, /name cannot be empty/)

    workflow = described_class.new('No block', config: context.config)
    expect { workflow.run }.to raise_error(ArgumentError, /workflow block is required/)
    expect { workflow.step('No block') }.to raise_error(ArgumentError, /step block is required/)
  end

  def event_payload(name)
    instrumenter.events.find { |event_name, _payload| event_name == name }.last
  end

  def workflow_event(workflow_id)
    instrumenter.events
                .filter_map { |name, payload| payload if name == 'workflow.ruby_llm' }
                .find { |payload| payload[:workflow_id] == workflow_id }
  end
end
