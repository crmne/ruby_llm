# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Tool do
  include_context 'with configured RubyLLM'

  let(:runs) { [] }

  let(:book_flight) do
    started = runs
    Class.new(RubyLLM::Tool) do
      def self.name = 'BookFlight'

      description 'Books a flight'
      parameter :destination

      define_method(:execute) do |destination:|
        started << destination
        seat = ask('Window or aisle?', choices: %w[window aisle]) or next 'No seat chosen'
        "Booked a #{seat} seat to #{destination}"
      end
    end
  end

  let(:chat) { RubyLLM::Chat.new(model: model_for(:anthropic)) }

  def tool_call(name, arguments = {})
    RubyLLM::Message.new(role: :assistant, content: '',
                         tool_calls: { 'call_1' => RubyLLM::ToolCall.new(id: 'call_1', name:, arguments:) })
  end

  def answer
    RubyLLM::Message.new(role: :assistant, content: 'Done', model: model_for(:anthropic), input_tokens: 1,
                         output_tokens: 1)
  end

  def result
    chat.messages.find { |message| message.role == :tool }&.content
  end

  def asking(tool, arguments = {})
    allow(chat.provider).to receive(:complete).and_return(tool_call(tool.tool_name, arguments), answer)
    chat.with_tools(tool).ask('Go')
  end

  def tool(&execute)
    Class.new(RubyLLM::Tool) do
      def self.name = 'Survey'

      description 'Asks the person'
      define_method(:execute, &execute)
    end
  end

  it 'pauses the call on its question, and runs it again with the answer' do
    asking(book_flight, 'destination' => 'Lisbon')

    expect(chat).to be_waiting
    question = chat.pending_questions.sole
    expect(question).to have_attributes(message: 'Window or aisle?', url: nil,
                                        tool_call: have_attributes(name: 'book_flight'))
    expect(question.fields.sole).to have_attributes(choices: %w[window aisle], required?: true)
    expect(question).not_to be_approval

    question.answer 'aisle'
    chat.complete

    expect(result).to eq('Booked a aisle seat to Lisbon')
    expect(runs).to eq(%w[Lisbon Lisbon])
    expect(chat.pending_questions).to be_empty
  end

  it 'returns nil for a declined question' do
    asking(book_flight, 'destination' => 'Lisbon')

    chat.pending_questions.sole.decline
    chat.complete

    expect(result).to eq('No seat chosen')
  end

  it 'refuses a choice it did not offer' do
    asking(book_flight, 'destination' => 'Lisbon')

    expect { chat.pending_questions.sole.answer('middle') }
      .to raise_error(ArgumentError, /"middle" is not one of the choices/)
    expect(chat.pending_questions.sole).not_to be_answered
  end

  it 'asks for free text' do
    asking(tool { "Hello, #{ask('What is your name?')}" })

    question = chat.pending_questions.sole
    expect(question.fields.sole).to have_attributes(type: 'string', choices: nil, required?: true)

    question.answer 'Ada'
    chat.complete

    expect(result).to eq('Hello, Ada')
  end

  it 'asks for the fields a block declares, and returns their values by name' do
    asking(tool do
      passenger = ask('Who is flying?') do
        string :name, description: 'As on the passport'
        integer :age, required: false
      end
      passenger.inspect
    end)

    question = chat.pending_questions.sole
    expect(question.fields.map(&:name)).to eq(%i[name age])

    question.answer(name: 'Ada', age: '36')
    chat.complete

    expect(result).to eq({ name: 'Ada', age: 36 }.inspect)
  end

  it 'asks the person to visit a page, and returns true once they say they did' do
    asking(tool { ask('Connect your calendar', url: 'https://example.com/connect') ? 'Connected' : 'Not connected' })

    question = chat.pending_questions.sole
    expect(question).to have_attributes(url: 'https://example.com/connect', url?: true, fields: [])

    question.answer
    chat.complete

    expect(result).to eq('Connected')
  end

  it 'returns nil for a page the person declines to visit' do
    asking(tool { ask('Connect your calendar', url: 'https://example.com/connect') ? 'Connected' : 'Not connected' })

    chat.pending_questions.sole.decline
    chat.complete

    expect(result).to eq('Not connected')
  end

  it 'refuses choices with nothing to choose' do
    expect { tool { ask('Pick one', choices: []) }.new.call }
      .to raise_error(ArgumentError, 'choices: needs at least one choice.')
  end

  it 'asks several questions one after another' do
    asking(tool { "#{ask('Name?')} likes #{ask('Color?', choices: %w[red blue])}" })
    chat.pending_questions.sole.answer('Ada')
    chat.complete

    expect(chat.pending_questions.map(&:message)).to eq(['Color?'])

    chat.pending_questions.sole.answer('blue')
    chat.complete

    expect(result).to eq('Ada likes blue')
  end

  it 'gives each question its own id, which the chat answers by' do
    asking(tool { "#{ask('Name?')} likes #{ask('Color?')}" })
    first = chat.pending_questions.sole
    chat.answer(first.id, 'Ada').complete
    second = chat.pending_questions.sole

    expect(second.id).not_to eq(first.id)
    expect([first.id, second.id]).to all(start_with("#{first.tool_call.id}/"))

    chat.answer(second.id, 'blue').complete

    expect(result).to eq('Ada likes blue')
  end

  it 'pauses on a task after its question, and resumes the task' do
    deploy = Class.new(RubyLLM::Tool) do
      def self.name = 'Deploy'

      description 'Deploy after asking'

      def execute
        target = ask('Where?', choices: %w[staging production])
        RubyLLM::Task.new(status: :input_required, data: { 'target' => target })
      end

      def resume(task, **) = "Deployed to #{task.data['target']}"
    end
    asking(deploy)

    chat.pending_questions.sole.answer('staging')
    chat.complete

    expect(chat.waiting? && chat.pending_tasks.any?).to be(true)
    expect(chat.pending_tasks.sole.data).to eq('target' => 'staging')

    chat.complete

    expect(result).to eq('Deployed to staging')
  end

  it 'keeps the questions of a tool it calls apart from its own' do
    inner = Class.new(RubyLLM::Tool) do
      def self.name = 'Inner'

      description 'Asks its own question'

      def execute
        ask('Inner?')
        'Inner answered'
      end
    end
    asking(tool do
      name = ask('Name?')
      inner_result = begin
        inner.new.call
      rescue RubyLLM::InputRequiredError => e
        "Inner asked #{e.requests.map(&:message).join}"
      end
      "#{name} likes #{ask('Color?')}. #{inner_result}"
    end)

    chat.pending_questions.sole.answer('Ada')
    chat.complete

    expect(chat.pending_questions.map(&:message)).to eq(['Color?'])

    chat.pending_questions.sole.answer('blue')
    chat.complete

    expect(result).to eq('Ada likes blue. Inner asked Inner?')
  end

  it 'refuses arguments that ask for two kinds of answer' do
    page = tool { ask('Connect', url: 'https://example.com', choices: %w[yes no]) }
    form = tool { ask('Who?', choices: %w[a b]) { string :name } }

    expect { page.new.call }.to raise_error(ArgumentError, /one kind of answer/)
    expect { form.new.call }.to raise_error(ArgumentError, /one kind of answer/)
  end

  it 'raises outside a chat, with the question it asked' do
    expect { book_flight.new.call(destination: 'Lisbon') }
      .to raise_error(RubyLLM::InputRequiredError, /BookFlight|book_flight/) { |error|
        expect(error.requests.map(&:message)).to eq(['Window or aisle?'])
        expect(error.requests.sole).to be_a(RubyLLM::Question)
        expect(error.requests.sole.key).to eq('ask_0')
      }
  end

  it 'reads the answers it is resumed with outside a chat' do
    question = RubyLLM::Question.asked(0, 'Window or aisle?', choices: %w[window aisle])
    input = { 'requests' => [question.respond({ 'action' => 'accept', 'content' => { 'answer' => 'aisle' } }).to_h] }

    expect(book_flight.new.resume_call(input, { destination: 'Lisbon' }, tool_call: nil))
      .to eq('Booked a aisle seat to Lisbon')
  end

  describe 'an answer given to another question' do
    let(:draft) { { present: true } }
    let(:seats) { %w[window aisle] }

    it 'asks a question again when a run skips the one answered in its place' do
      present = draft
      asking(tool do
        keep = ask('Keep the draft?', choices: %w[yes no]) if present[:present]
        wipe = ask('Delete every card?', choices: %w[yes no])
        "keep: #{keep.inspect}, wipe: #{wipe.inspect}"
      end)
      chat.pending_questions.sole.answer('yes')
      chat.complete
      chat.pending_questions.sole.answer('no')
      draft[:present] = false
      chat.complete

      expect(result).to be_nil
      expect(chat.pending_questions.map(&:message)).to eq(['Delete every card?'])

      chat.pending_questions.sole.answer('no')
      chat.complete

      expect(result).to eq('keep: nil, wipe: "no"')
    end

    it 'asks again when the choices changed while the person decided' do
      offered = seats
      asking(tool { "Seat #{ask('Which seat?', choices: offered)}" })
      first = chat.pending_questions.sole
      first.answer('aisle')
      seats.replace(%w[front back])
      chat.complete

      expect(result).to be_nil
      question = chat.pending_questions.sole
      expect(question.fields.sole.choices).to eq(%w[front back])
      expect(question.id).not_to eq(first.id)

      chat.answer(question.id, 'back').complete

      expect(result).to eq('Seat back')
    end

    it 'asks again when another message takes the place' do
      wording = ['Delete every card?']
      asking(tool { ask(wording.first, choices: %w[yes no]).inspect })
      chat.pending_questions.sole.answer('yes')
      wording.replace(['Delete every card in the deck?'])
      chat.complete

      expect(chat.pending_questions.map(&:message)).to eq(['Delete every card in the deck?'])
    end

    it 'asks for fields where a choice was answered' do
      fields = [false]
      asking(tool do
        (fields.first ? ask('Which seat?') { string :row } : ask('Which seat?', choices: %w[window aisle])).inspect
      end)
      chat.pending_questions.sole.answer('aisle')
      fields.replace([true])
      chat.complete

      expect(chat.pending_questions.sole.fields.map(&:name)).to eq([:row])
    end

    it 'asks the questions after a changed one again, keeping the answers before it' do
      wording = ['Color?']
      asking(tool { "#{ask('Name?')} likes #{ask(wording.first)} and #{ask('Food?')}" })
      chat.pending_questions.sole.answer('Ada')
      chat.complete
      chat.pending_questions.sole.answer('blue')
      chat.complete
      wording.replace(['Colour?'])
      chat.pending_questions.sole.answer('figs')
      chat.complete

      expect(chat.pending_questions.map(&:message)).to eq(['Colour?'])

      chat.pending_questions.sole.answer('green')
      chat.complete

      expect(chat.pending_questions.map(&:message)).to eq(['Food?'])

      chat.pending_questions.sole.answer('pears')
      chat.complete

      expect(result).to eq('Ada likes green and pears')
    end

    it 'keeps a declined question declined when the question is the same' do
      asking(book_flight, 'destination' => 'Lisbon')
      chat.pending_questions.sole.decline('Later')
      chat.complete

      expect(result).to start_with('No seat chosen')
    end

    it 'takes a page to visit as the same question under a new address' do
      visits = []
      asking(tool do
        visits << "https://example.com/connect?state=#{visits.size}"
        ask('Connect your calendar', url: visits.last) ? 'Connected' : 'Not connected'
      end)
      chat.pending_questions.sole.answer
      chat.complete

      expect(result).to eq('Connected')
    end
  end

  it 'reads an answer whose question was stored with its keys in another order' do
    question = RubyLLM::Question.asked(0, 'Who is flying?', schema: RubyLLM::Tool::SchemaDefinition.new(block: proc do
      string :name
      integer :age, required: false
    end).json_schema)
    stored = JSON.parse(JSON.generate(question.respond({ 'action' => 'accept',
                                                         'content' => { 'name' => 'Ada' } }).to_h))
    stored['params'] = stored['params'].to_a.reverse.to_h
    stored['params']['requestedSchema'] = stored['params']['requestedSchema'].to_a.reverse.to_h
    passenger = tool do
      ask('Who is flying?') do
        string :name
        integer :age, required: false
      end.inspect
    end

    expect(passenger.new.resume_call({ 'requests' => [stored] }, {}, tool_call: nil)).to eq({ name: 'Ada' }.inspect)
  end

  it 'reads an answer stored before questions were compared, without an id' do
    stored = {
      'key' => 'ask_0',
      'params' => { 'mode' => 'form', 'message' => 'Window or aisle?',
                    'requestedSchema' => { 'type' => 'object',
                                           'properties' => { 'answer' => { 'type' => 'string',
                                                                           'enum' => %w[window aisle] } },
                                           'required' => ['answer'] } },
      'response' => { 'action' => 'accept', 'content' => { 'answer' => 'aisle' } }
    }

    expect(book_flight.new.resume_call({ 'requests' => [stored] }, { destination: 'Lisbon' }, tool_call: nil))
      .to eq('Booked a aisle seat to Lisbon')
  end

  it 'keeps a server question as the same object, under its old names' do
    expect(RubyLLM::MCP::InputRequest).to be(RubyLLM::Question)
    expect(RubyLLM::MCP::InputRequiredError.ancestors).to include(RubyLLM::InputRequiredError)
  end
end
