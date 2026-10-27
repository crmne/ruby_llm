# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Workflow do
  include_context 'with configured RubyLLM'

  let(:instrumenter) { CaptureInstrumenter.new }
  let(:context) { RubyLLM.context { |config| config.instrumenter = instrumenter } }

  it 'adds workflow and step identity to every nested instrumentation event' do
    result = context.workflow('Write article', id: 'article-42') do |workflow|
      workflow.step('Research', id: 'research-1') do
        RubyLLM::Support::Instrumentation.instrument('example.ruby_llm', config: context.config) { :notes }
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
        RubyLLM::Support::Instrumentation.instrument('example.ruby_llm', metadata: { request: 'r-1' },
                                                                         config: context.config)
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
            RubyLLM::Support::Instrumentation.instrument('example.ruby_llm', config: context.config)
          end
        end
        RubyLLM::Support::Instrumentation.instrument('resumed.ruby_llm', config: context.config)
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

  it 'recomputes parent links each time a workflow runs' do
    reusable = described_class.new('Reusable', id: 'reusable', config: context.config)

    context.workflow('Outer', id: 'outer') do |outer|
      outer.step('Nested', id: 'nested') { reusable.run { :nested } }
    end
    reusable.run { :top_level }

    events = instrumenter.events.filter_map do |name, payload|
      payload if name == 'workflow.ruby_llm' && payload[:workflow_id] == 'reusable'
    end
    expect(events.first).to include(workflow_parent_id: 'outer', workflow_parent_step_id: 'nested')
    expect(events.last).not_to have_key(:workflow_parent_id)
    expect(events.last).not_to have_key(:workflow_parent_step_id)
  end

  it 'restores the previous instrumentation context after errors' do
    expect do
      context.workflow('Failing', id: 'failing-1') do |workflow|
        workflow.step('Explode') { raise 'boom' }
      end
    end.to raise_error(RuntimeError, 'boom')

    RubyLLM::Support::Instrumentation.instrument('after.ruby_llm', config: context.config)

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

  it 'passes workflow and step identity to a child fiber' do
    child = context.workflow('Search', id: 'search-1') do |workflow|
      workflow.step('Embed', id: 'embed-1') do
        Fiber.new { RubyLLM.instrument('child.ruby_llm', config: context.config) }
      end
    end
    child.resume

    expect(event_payload('child.ruby_llm')).to include(workflow_id: 'search-1', workflow_step_id: 'embed-1')
    expect(RubyLLM::Support::Instrumentation.current_workflow).to be_nil
  end

  it 'isolates overlapping async steps from their siblings and caller' do
    in_reactor do |task|
      task.with_timeout(2) do
        require 'async/queue'
        release = Async::Queue.new
        context.workflow('Search', id: 'search-1') do |workflow|
          children = %w[first second].map do |id|
            task.async do
              workflow.step(id, id:) do
                release.pop
                RubyLLM.instrument("#{id}.ruby_llm", config: context.config)
              end
            end
          end
          2.times { release << true }
          children.each(&:wait)
          RubyLLM.instrument('caller.ruby_llm', config: context.config)
        end
      end
    end

    %w[first second].each do |id|
      expect(event_payload("#{id}.ruby_llm")).to include(workflow_id: 'search-1', workflow_step_id: id)
      expect(event_payload("#{id}.ruby_llm")).not_to have_key(:workflow_step_parent_id)
    end
    expect(event_payload('caller.ruby_llm')).to include(workflow_id: 'search-1')
    expect(event_payload('caller.ruby_llm')).not_to have_key(:workflow_step_id)
  end

  it 'links a child fiber workflow to its parent step and restores that step after errors' do
    context.workflow('Outer', id: 'outer-1') do |workflow|
      workflow.step('Compose', id: 'compose-1') do
        Fiber.new do
          expect do
            context.workflow('Inner', id: 'inner-1') do |inner|
              inner.step('Fail') do
                RubyLLM.instrument('inner.ruby_llm', config: context.config)
                raise 'failure'
              end
            end
          end.to raise_error(RuntimeError, 'failure')
          RubyLLM.instrument('resumed.ruby_llm', config: context.config)
        end.resume
      end
    end

    expect(event_payload('inner.ruby_llm')).to include(workflow_parent_id: 'outer-1',
                                                       workflow_parent_step_id: 'compose-1')
    expect(event_payload('resumed.ruby_llm')).to include(workflow_id: 'outer-1', workflow_step_id: 'compose-1')
    expect(RubyLLM::Support::Instrumentation.current_workflow).to be_nil
  end

  it 'passes the workflow to child threads without leaking it to subsequent work' do
    context.workflow('Search', id: 'search-1') do |workflow|
      workflow.step('Embed', id: 'embed-1') do
        Thread.new { RubyLLM.instrument('child.ruby_llm', config: context.config) }.value
      end
    end
    Thread.new { RubyLLM.instrument('unrelated.ruby_llm', config: context.config) }.value

    expect(event_payload('child.ruby_llm')).to include(workflow_id: 'search-1', workflow_step_id: 'embed-1')
    expect(event_payload('unrelated.ruby_llm')).not_to have_key(:workflow_id)
  end

  it 'respects fibers that explicitly disable workflow storage inheritance' do
    context.workflow('Search', id: 'search-1') do
      Fiber.new(storage: nil) { RubyLLM.instrument('child.ruby_llm', config: context.config) }.resume
    end

    expect(event_payload('child.ruby_llm')).not_to have_key(:workflow_id)
  end

  def workflow_event(workflow_id)
    instrumenter.events
                .filter_map { |name, payload| payload if name == 'workflow.ruby_llm' }
                .find { |payload| payload[:workflow_id] == workflow_id }
  end
end
