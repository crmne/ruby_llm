# frozen_string_literal: true

require 'spec_helper'

# What an app shows a person under a form when their answer can't be taken.
RSpec.describe RubyLLM::Question do
  def form(properties, required = [])
    described_class.new('profile', { 'message' => 'Your profile',
                                     'requestedSchema' => { 'properties' => properties, 'required' => required } })
  end

  def refusal(question, ...)
    question.answer(...)
  rescue ArgumentError => e
    e.message
  end

  it 'names an untitled field as a person reads it, in a whole sentence' do
    question = form({ 'release_name' => { 'type' => 'string' }, 'notes' => { 'type' => 'string' } }, ['release_name'])

    expect { question.answer(notes: 'x') }.to raise_error(ArgumentError, 'Release name needs an answer.')
  end

  it 'ends a titled field’s refusal with a full stop' do
    question = form({ 'environment' => { 'type' => 'string', 'title' => 'Environment' } }, ['environment'])

    expect { question.answer({}) }.to raise_error(ArgumentError, 'Environment needs an answer.')
  end

  it 'takes a text answer without the spaces around it' do
    question = form('environment' => { 'type' => 'string' })

    question.answer('  staging ')

    expect(question.response['content']).to eq('environment' => 'staging')
  end

  it 'names a field in words, keeping the capitals of an abbreviation' do
    names = %w[releaseName release-name customerID URLPath api_key]
    questions = names.map { |name| form({ name => { 'type' => 'string' }, 'notes' => { 'type' => 'string' } }, [name]) }

    expect(questions.map { |question| refusal(question, notes: 'x') })
      .to eq(['Release name needs an answer.', 'Release name needs an answer.', 'Customer ID needs an answer.',
              'URL path needs an answer.', 'Api key needs an answer.'])
  end

  it 'calls the one field of a question without a title the question' do
    question = form({ 'answer' => { 'type' => 'integer' } }, ['answer'])

    expect(refusal(question, ' ')).to eq('The question needs an answer.')
    expect(refusal(question, 'many')).to eq('The question takes a whole number.')
  end

  it 'counts text of spaces alone as left out' do
    question = form({ 'environment' => { 'type' => 'string', 'title' => 'Environment' },
                      'notes' => { 'type' => 'string' } }, ['environment'])

    expect { question.answer(environment: " \t\n ", notes: '   ') }
      .to raise_error(ArgumentError, 'Environment needs an answer.')
  end

  it 'takes the text of a list without the spaces around each item, leaving out blank ones' do
    question = form('tags' => { 'type' => 'array', 'items' => { 'type' => 'string', 'enum' => %w[red green] } })

    question.answer(tags: [' red ', '  ', "green\n"])

    expect(question.response['content']).to eq('tags' => %w[red green])
  end

  it 'takes a choice and a switch typed with spaces around them' do
    question = form('seat' => { 'type' => 'string', 'enum' => %w[window aisle] }, 'window' => { 'type' => 'boolean' },
                    'seats' => { 'type' => 'integer' })

    question.answer(seat: ' aisle ', window: ' Yes ', seats: ' 2 ')

    expect(question.response['content']).to eq('seat' => 'aisle', 'window' => true, 'seats' => 2)
  end

  it 'names the choices in words when an answer is not one of them' do
    two = form('seat' => { 'type' => 'string', 'enum' => %w[window aisle] })
    four = form('seat' => { 'type' => 'string', 'enum' => ['window', 'aisle', 'exit row', 'bulkhead'] })

    expect { two.answer('middle') }
      .to raise_error(ArgumentError, '"middle" is not one of the choices: window or aisle.')
    expect { four.answer(' middle ') }
      .to raise_error(ArgumentError, '"middle" is not one of the choices: window, aisle, exit row, or bulkhead.')
  end

  it 'says a value of the wrong type in a whole sentence' do
    question = form('seats' => { 'type' => 'integer' }, 'first_name' => { 'type' => 'string' },
                    'window' => { 'type' => 'boolean' }, 'meals' => { 'type' => 'array' },
                    'price' => { 'type' => 'number' })

    expect([refusal(question, seats: 'two'), refusal(question, first_name: 36), refusal(question, window: 'maybe'),
            refusal(question, meals: { 'a' => 1 }), refusal(question, price: 'free')])
      .to eq(['Seats takes a whole number.', 'First name takes text.', 'Window takes true or false.',
              'Meals takes a list.', 'Price takes a number.'])
  end

  it 'names the fields it asks for, and those it does not, in whole sentences' do
    question = form('name' => { 'type' => 'string' }, 'age' => { 'type' => 'integer' },
                    'city' => { 'type' => 'string' })

    expect(refusal(question, 'Ada')).to eq('The question asks for name, age, and city: give each by name.')
    expect(refusal(question, name: 'Ada', role: 'x')).to eq('The question does not ask for role.')
    expect(refusal(question, role: 'x', team: 'y')).to eq('The question does not ask for role or team.')
  end

  it 'says in a whole sentence that an approval or a page to visit takes no answer' do
    page = described_class.new('connect', { 'mode' => 'url', 'url' => 'https://example.com/connect' })
    approval = described_class.new('approval', {}, approval: true)

    expect(refusal(page, 'done')).to eq('A page to visit takes no answer.')
    expect(refusal(approval, 'yes')).to eq('An approval takes no answer.')
  end

  it 'says in a whole sentence that a question is not an approval' do
    question = form('name' => { 'type' => 'string' })

    expect { question.approve }.to raise_error(ArgumentError, 'This question is not an approval: answer it instead.')
    expect { question.deny }.to raise_error(ArgumentError, 'This question is not an approval: decline it instead.')
  end
end
