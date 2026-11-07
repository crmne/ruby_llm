# frozen_string_literal: true

require 'rails_helper'
require 'active_support/testing/time_helpers'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'
  include ActiveSupport::Testing::TimeHelpers

  after { travel_back }

  let(:ran) { [] }
  let(:replies) { Hash.new { |all, instructions| all[instructions] = [] } }
  let(:requests) { Hash.new { |all, instructions| all[instructions] = [] } }

  before do
    define_tools
    define_agents
    scripted = replies
    asked = requests
    allow_any_instance_of(RubyLLM::Providers::OpenAI).to receive(:complete) do |_provider, messages, **| # rubocop:disable RSpec/AnyInstance
      system, conversation = messages.partition { |message| message.role == :system }
      instructions = system.sole.content
      asked[instructions] << conversation.map { |message| [message.role, message.content.to_s] }
      reply = scripted[instructions].shift or raise "#{instructions} asked the model more often than scripted"
      reply.is_a?(Proc) ? reply.call : reply
    end
  end

  def define_tools
    runs = ran
    stub_const('Wipe', Class.new(RubyLLM::Tool) do
      description 'Wipes the cache'
      requires_approval
      define_method(:execute) do
        runs << :wipe
        'Wiped'
      end
    end)
    stub_const('Lookup', Class.new(RubyLLM::Tool) do
      description 'Looks something up'
      define_method(:execute) do
        runs << :lookup
        'Found'
      end
    end)
  end

  def define_agents
    stub_const('ResearchAgent', Class.new(RubyLLM::Agent) do
      chat_class Chat
      model model_for(:openai), provider: :openai
      description 'Researches a question and reports back'
      instructions 'Research.'
      tools Wipe, Lookup
    end)
    stub_const('LeadAgent', Class.new(RubyLLM::Agent) do
      chat_class Chat
      model model_for(:openai), provider: :openai
      instructions 'Lead.'
      tools ResearchAgent, Wipe
    end)
  end

  def answer(content)
    RubyLLM::Message.new(role: :assistant, content:, input_tokens: 1, output_tokens: 1)
  end

  def calling(*calls)
    tool_calls = calls.to_h do |name, arguments|
      id = "call_#{SecureRandom.hex(6)}"
      [id, RubyLLM::ToolCall.new(id:, name:, arguments: arguments || {})]
    end
    RubyLLM::Message.new(role: :assistant, content: '', input_tokens: 1, output_tokens: 1, tool_calls:)
  end

  def research(task = 'Wipe the cache')
    ['research_agent', { 'task' => task }]
  end

  def calls_of(chat)
    RubyLLM::ActiveRecord::ToolCall.where(message_type: 'Message',
                                          message_id: Message.where(chat_id: chat.id).select(:id))
  end

  def subagent_chat(chat)
    calls_of(chat).find_by!(name: 'research_agent').subagent_chat
  end

  def transcript(chat)
    Message.where(chat_id: chat.id).order(:created_at, :id).pluck(:role, :content)
  end

  # The chat a request's process ran, which the subagent now waits in for
  # a decision on its wipe call.
  def waiting_lead(*lead_replies)
    replies['Lead.'].push(calling(research), *lead_replies)
    replies['Research.'].push(calling('wipe'))
    LeadAgent.create!.tap { |lead| lead.ask('Clean up') }
  end

  # What a worker leaves when it dies: its claims outlive it by up to a lease.
  def leave_claims_of_a_dead_process(*chats)
    claimed_until = RubyLLM::ActiveRecord::RunClaims::CLAIM_LEASE.seconds.from_now
    Chat.where(id: chats).update_all(claim_token: 'dead', claimed_until:)
    chats.each { |chat| calls_of(chat).where(result_id: nil).update_all(claimed_until:) }
  end

  describe 'a subagent whose agent has a chat_class' do
    it 'runs in a chat its agent creates, linked to the call that started it' do
      lead = waiting_lead

      research = subagent_chat(lead)

      expect(research).to be_a(Chat).and(be_persisted)
      expect(transcript(research)).to eq([%w[system Research.], ['user', 'Wipe the cache'], ['assistant', '']])
      expect(ResearchAgent.find(research.id)).to be_awaiting_approval
      expect(LeadAgent.find(lead.id).pending_tasks.sole.agent).to eq(research)
    end

    it 'carries on in another process once the approval it waits for is recorded there' do
      lead = waiting_lead(answer('All clean'))
      replies['Research.'].push(answer('Cache wiped.'))

      approval = LeadAgent.find(lead.id).pending_approvals.sole
      LeadAgent.find(lead.id).approve(approval.tool_call_id)
      reply = LeadAgent.find(lead.id).complete

      expect(reply.content).to eq('All clean')
      expect(ran).to eq([:wipe])
      expect(requests['Lead.'].last.last).to eq([:tool, 'Cache wiped.'])
      expect(transcript(subagent_chat(lead))).to eq(
        [%w[system Research.], ['user', 'Wipe the cache'], ['assistant', ''], %w[tool Wiped],
         ['assistant', 'Cache wiped.']]
      )
    end

    it 'carries on the subagent of a process that died while it ran, once its claims expire' do
      stub_const('ProcessDied', Class.new(Exception)) # rubocop:disable Lint/InheritException
      replies['Lead.'].push(calling(research('Look it up')), answer('Here it is'))
      replies['Research.'].push(-> { raise ProcessDied }, answer('Found it.'))
      lead = LeadAgent.create!
      expect { lead.ask('Find it') }.to raise_error(ProcessDied)
      research = subagent_chat(lead)
      leave_claims_of_a_dead_process(lead, research)

      waiting = LeadAgent.find(lead.id)
      waiting.complete
      expect(waiting).to be_waiting
      travel RubyLLM::ActiveRecord::RunClaims::CLAIM_LEASE + 1

      expect(LeadAgent.find(lead.id).complete.content).to eq('Here it is')
      expect(subagent_chat(lead)).to eq(research)
      expect(transcript(research).reject { |_role, content| content.blank? })
        .to eq([%w[system Research.], ['user', 'Look it up'], ['assistant', 'Found it.']])
    end

    it 'keeps an agent without a chat_class in the process that ran it' do
      stub_const('PlainResearch', Class.new(RubyLLM::Agent) do
        model model_for(:openai), provider: :openai
        instructions 'Research.'
        tools Wipe
      end)
      LeadAgent.tools PlainResearch, Wipe
      replies['Lead.'].push(calling(['plain_research', { 'task' => 'Wipe the cache' }]), answer('Lost it'))
      replies['Research.'].push(calling('wipe'))
      lead = LeadAgent.create!
      lead.ask('Clean up')

      expect(lead.pending_tasks.sole.agent).to be_a(PlainResearch)
      expect(LeadAgent.find(lead.id).pending_approvals).to be_empty
      expect(LeadAgent.find(lead.id).complete.content).to eq('Lost it')
      expect(requests['Lead.'].last.last.last).to include('lost')
    end
  end

  describe 'approvals' do
    it 'lists what its subagents wait for after its own calls, and decides them' do
      replies['Lead.'].push(calling(research, 'wipe'), answer('Done'))
      replies['Research.'].push(calling('wipe'), answer('Cache wiped.'))
      lead = LeadAgent.create!
      lead.ask('Clean up')

      web = LeadAgent.find(lead.id)
      own, delegated = web.pending_approvals.to_a
      expect(web).to be_awaiting_approval
      expect([own, delegated].map(&:name)).to eq(%w[wipe wipe])
      expect(own.message.chat).to eq(lead)
      expect(delegated.message.chat).to eq(subagent_chat(lead))

      web.deny(own.tool_call_id)
      web.approve(delegated)
      expect(LeadAgent.find(lead.id).pending_approvals).to be_empty

      expect(LeadAgent.find(lead.id).complete.content).to eq('Done')
      expect(ran).to eq([:wipe])
      expect(own.reload.result.content).to include('denied')
      expect(delegated.reload.result.content).to eq('Wiped')
    end

    it 'denies a subagent call it lists, and the subagent answers without it' do
      lead = waiting_lead(answer('Left it'))
      replies['Research.'].push(answer('Not allowed to wipe.'))

      LeadAgent.find(lead.id).deny(LeadAgent.find(lead.id).pending_approvals.sole)

      expect(LeadAgent.find(lead.id).complete.content).to eq('Left it')
      expect(ran).to be_empty
      expect(requests['Lead.'].last.last).to eq([:tool, 'Not allowed to wipe.'])
    end

    it 'remembers an approval for the rest of the subagent, not the chat that called it' do
      lead = waiting_lead
      LeadAgent.find(lead.id).approve(LeadAgent.find(lead.id).pending_approvals.sole, remember: true)

      decision = calls_of(subagent_chat(lead)).find_by!(name: 'wipe').approval

      expect(decision).to eq('remembered')
      expect(calls_of(lead).where(approval: 'remembered')).to be_empty
    end

    it "lists and decides the approvals of a subagent's own subagents, and carries each on" do
      stub_const('AuditAgent', Class.new(RubyLLM::Agent) do
        chat_class Chat
        model model_for(:openai), provider: :openai
        instructions 'Audit.'
        tools Wipe
      end)
      ResearchAgent.tools AuditAgent
      replies['Lead.'].push(calling(research('Audit it')), answer('All audited'))
      replies['Research.'].push(calling(['audit_agent', { 'task' => 'Wipe the cache' }]), answer('Audited.'))
      replies['Audit.'].push(calling('wipe'), answer('Wiped it.'))
      lead = LeadAgent.create!
      lead.ask('Audit everything')

      approval = LeadAgent.find(lead.id).pending_approvals.sole
      expect(approval.message.chat).to eq(calls_of(subagent_chat(lead)).find_by!(name: 'audit_agent').subagent_chat)
      LeadAgent.find(lead.id).approve(approval.tool_call_id)
      expect(LeadAgent.find(lead.id)).not_to be_awaiting_person

      expect(LeadAgent.find(lead.id).complete.content).to eq('All audited')
      expect(ran).to eq([:wipe])
      expect(requests['Research.'].last.last).to eq([:tool, 'Wiped it.'])
    end

    it 'approves each run_code call of a subagent on its own' do
      lead = waiting_lead
      research = subagent_chat(lead)
      research.add_message(calling(['run_code', { 'code' => 'puts 1', 'sandbox' => 'online' }]))
      row = calls_of(research).find_by!(name: 'run_code')
      row.update!(approval: 'pending')

      expect { LeadAgent.find(lead.id).approve(row.tool_call_id, remember: true) }
        .to raise_error(ArgumentError, /cannot be remembered/)
      expect(row.reload.approval).to eq('pending')
    end

    it "decides a subagent's call without the API key its agent's context supplies" do
      RubyLLM.config.openai_api_key = nil
      [LeadAgent, ResearchAgent].each { |agent| agent.context { |config| config.openai_api_key = 'agent-key' } }
      lead = waiting_lead(answer('All clean'))
      replies['Research.'].push(answer('Cache wiped.'))

      LeadAgent.find(lead.id).approve(LeadAgent.find(lead.id).pending_approvals.sole)

      expect(LeadAgent.find(lead.id).complete.content).to eq('All clean')
      expect(ran).to eq([:wipe])
    end

    it 'refuses a call that is neither its own nor a subagent of its' do
      wipe = calls_of(subagent_chat(waiting_lead)).find_by!(name: 'wipe')

      expect { LeadAgent.create!.approve(wipe.tool_call_id) }.to raise_error(ArgumentError, /Unknown tool call/)
    end

    it "stops waiting on a person once its subagent's last approval is recorded" do
      lead = waiting_lead

      LeadAgent.find(lead.id).approve(LeadAgent.find(lead.id).pending_approvals.sole)

      waiting = LeadAgent.find(lead.id)
      expect(waiting).to be_awaiting_tasks
      expect(waiting).not_to be_awaiting_person
      expect(waiting).not_to be_awaiting_approval
    end
  end

  describe 'cancellation' do
    it 'cancels the subagent it waits on when another process cancels it' do
      lead = waiting_lead

      LeadAgent.find(lead.id).cancel
      expect { LeadAgent.find(lead.id).complete }.to raise_error(RubyLLM::CancelledError)

      research = subagent_chat(lead)
      expect(ResearchAgent.find(research.id)).not_to be_waiting
      expect(calls_of(research).find_by!(name: 'wipe').result).to be_present
      expect(calls_of(lead).find_by!(name: 'research_agent').result).to be_present
      expect(LeadAgent.find(lead.id).pending_approvals).to be_empty
      expect(ran).to be_empty
    end

    it 'stops a working subagent when another process cancels the chat that called it' do
      stub_const("#{described_class}::CANCELLATION_POLL_INTERVAL", 0.0)
      lead = LeadAgent.create!
      replies['Lead.'].push(calling(research('Look it up')))
      replies['Research.'].push(lambda {
        LeadAgent.find(lead.id).cancel
        calling('lookup')
      })

      expect { lead.ask('Find it') }.to raise_error(RubyLLM::CancelledError)

      expect(ran).to be_empty
      expect(requests['Research.'].size).to eq(1)
      expect(ResearchAgent.find(subagent_chat(lead).id)).not_to be_running
      expect(LeadAgent.find(lead.id)).not_to be_waiting
    end
  end

  describe 'two processes' do
    it 'runs the approved call once when two jobs carry the chat on' do
      lead = waiting_lead(answer('All clean'))
      LeadAgent.find(lead.id).approve(LeadAgent.find(lead.id).pending_approvals.sole)
      first = LeadAgent.find(lead.id)
      second = LeadAgent.find(lead.id)
      overlap = {}
      replies['Research.'].push(lambda {
        overlap[:lead] = second.complete
        overlap[:research] = ResearchAgent.find(subagent_chat(lead).id).complete
        overlap[:waiting] = second.waiting?
        answer('Cache wiped.')
      })

      first.complete
      second.complete

      expect(ran).to eq([:wipe])
      expect(overlap).to include(waiting: true)
      expect(requests['Lead.'].size).to eq(2)
      expect(requests['Research.'].size).to eq(2)
      expect(LeadAgent.find(lead.id)).to be_complete
    end

    it 'carries on with a subagent approval recorded while it finished its run' do
      replies['Lead.'].push(calling(research), answer('All clean'))
      replies['Research.'].push(calling('wipe'), answer('Cache wiped.'))
      lead = LeadAgent.create!
      lead.ask_later('Clean up')
      approved = false
      allow(lead.to_llm).to receive(:complete).and_wrap_original do |original, *args, &block|
        original.call(*args, &block).tap do
          next if approved

          approved = true
          web = LeadAgent.find(lead.id)
          web.approve(web.pending_approvals.sole)
          LeadAgent.find(lead.id).complete
        end
      end

      expect(lead.complete.content).to eq('All clean')
      expect(ran).to eq([:wipe])
      expect(requests['Lead.'].size).to eq(2)
    end
  end

  describe 'usage' do
    it "records the subagent's requests on its chat, for the owner of the chat that called it" do
      account = Chat.create!(model: model_for(:openai))
      lead = LeadAgent.create!.with_owner(account)
      replies['Lead.'].push(calling(research), answer('All clean'))
      replies['Research.'].push(calling('wipe'), answer('Cache wiped.'))
      lead.ask('Clean up')
      LeadAgent.find(lead.id).approve(LeadAgent.find(lead.id).pending_approvals.sole)

      LeadAgent.find(lead.id).with_owner(account).complete

      own = RubyLLM::ActiveRecord::Usage.where(chat: lead)
      delegated = RubyLLM::ActiveRecord::Usage.where(chat: subagent_chat(lead))
      expect([own.count, delegated.count]).to eq([2, 2])
      expect(delegated.map(&:owner)).to all(eq(account))
    end
  end
end
