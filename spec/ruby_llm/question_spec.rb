# frozen_string_literal: true

require 'spec_helper'
require 'action_controller/metal/strong_parameters'

RSpec.describe RubyLLM::Question do
  def form(properties, required = [])
    described_class.new('profile', { 'message' => 'Your profile',
                                     'requestedSchema' => { 'properties' => properties, 'required' => required } })
  end

  it 'fills in the defaults of the fields an answer leaves out' do
    question = form('name' => { 'type' => 'string', 'default' => 'John Doe' },
                    'age' => { 'type' => 'integer', 'default' => 30 },
                    'verified' => { 'type' => 'boolean', 'default' => false },
                    'email' => { 'type' => 'string' })

    question.answer(age: 31)

    expect(question.response)
      .to eq('action' => 'accept', 'content' => { 'name' => 'John Doe', 'age' => 31, 'verified' => false })
  end

  it 'keeps the values an answer gives' do
    question = form('status' => { 'type' => 'string', 'enum' => %w[active inactive], 'default' => 'active' })

    question.answer(status: 'inactive')

    expect(question).to be_answered
    expect(question.response['content']).to eq('status' => 'inactive')
  end

  it 'takes the one value of a question with one field' do
    question = form('environment' => { 'type' => 'string', 'enum' => %w[staging production] })

    question.answer('production')

    expect(question.response['content']).to eq('environment' => 'production')
  end

  it 'takes the values of a question with several fields by name, or as a Hash' do
    question = form('name' => { 'type' => 'string' }, 'age' => { 'type' => 'integer' })

    expect { question.answer('Ada') }.to raise_error(ArgumentError, /asks for name and age/)

    question.answer({ 'name' => 'Ada', 'age' => 36 })

    expect(question.response['content']).to eq('name' => 'Ada', 'age' => 36)
  end

  it 'turns the Strings a form sends into the types the fields ask for' do
    question = form('seats' => { 'type' => 'integer' }, 'budget' => { 'type' => 'number' },
                    'window' => { 'type' => 'boolean' }, 'meals' => { 'type' => 'array' })

    question.answer(seats: '2', budget: '149.5', window: '1', meals: ['', 'vegetarian'])

    expect(question.response['content'])
      .to eq('seats' => 2, 'budget' => 149.5, 'window' => true, 'meals' => ['vegetarian'])

    question.answer(meals: 'vegetarian')

    expect(question.response['content']).to eq('meals' => ['vegetarian'])
  end

  it 'leaves out a multi-select answered with nothing but blanks' do
    question = form('meals' => { 'type' => 'array' }, 'seats' => { 'type' => 'integer' })

    question.answer(meals: [''], seats: '1')

    expect(question.response['content']).to eq('seats' => 1)
  end

  it 'keeps its id when saved and loaded, and takes the key of one saved without an id' do
    question = form('name' => { 'type' => 'string' })

    expect(described_class.from_h(question.to_h).id).to eq(question.id)
    expect(described_class.from_h(question.to_h.except('id')).id).to eq('profile')
    expect(question.id).not_to eq('profile')
  end

  it 'refuses a value that is not of the type a field asks for' do
    question = form('seats' => { 'type' => 'integer', 'title' => 'Seats' }, 'name' => { 'type' => 'string' },
                    'window' => { 'type' => 'boolean' }, 'meals' => { 'type' => 'array' })

    expect { question.answer(seats: 'two') }.to raise_error(ArgumentError, /Seats takes a whole number/)
    expect { question.answer(seats: { value: 2 }) }.to raise_error(ArgumentError, /Seats takes a whole number/)
    expect { question.answer(seats: 2.5) }.to raise_error(ArgumentError, /Seats takes a whole number/)
    expect { question.answer(name: 36) }.to raise_error(ArgumentError, /Name takes text/)
    expect { question.answer(window: 'maybe') }.to raise_error(ArgumentError, /Window takes true or false/)
    expect { question.answer(meals: { 'a' => 1 }) }.to raise_error(ArgumentError, /Meals takes a list/)
    expect(question).not_to be_answered
  end

  it 'takes values of the type a field asks for, and a Symbol as text' do
    question = form('seats' => { 'type' => 'number' }, 'name' => { 'type' => 'string', 'enum' => %w[ada grace] },
                    'window' => { 'type' => 'boolean' }, 'notes' => {})

    question.answer(seats: 2, name: :ada, window: false, notes: { 'any' => 'thing' })

    expect(question.response['content'])
      .to eq('seats' => 2, 'name' => 'ada', 'window' => false, 'notes' => { 'any' => 'thing' })
  end

  it 'lists the choices of fields that give them titles' do
    sizes = [{ 'const' => 's', 'title' => 'Small' }, { 'const' => 'l', 'title' => 'Large' }]
    question = form('size' => { 'type' => 'string', 'oneOf' => sizes },
                    'tags' => { 'type' => 'array', 'items' => { 'anyOf' => [{ 'const' => 'a', 'title' => 'A' }] } })

    expect(question.fields.map(&:choices)).to eq([%w[s l], %w[a]])
  end

  it 'gives each choice the title its field gives it' do
    sizes = [{ 'const' => 's', 'title' => 'Small' }, { 'const' => 'l', 'title' => 'Large' }]
    question = form('size' => { 'type' => 'string', 'oneOf' => sizes },
                    'tags' => { 'type' => 'array', 'items' => { 'anyOf' => [{ 'const' => 'a', 'title' => 'A' }] } })

    expect(question.fields.map(&:choice_titles)).to eq([{ 's' => 'Small', 'l' => 'Large' }, { 'a' => 'A' }])
  end

  it 'reads the titles of choices from the names listed beside them' do
    question = form('size' => { 'type' => 'string', 'enum' => %w[s l], 'enumNames' => %w[Small Large] })

    expect(question.fields.first)
      .to have_attributes(choices: %w[s l], choice_titles: { 's' => 'Small', 'l' => 'Large' })
  end

  it 'titles a choice with its value when the field gives it no title' do
    cards = [{ 'const' => '17', 'title' => 'bank' }, { 'const' => '42' }]
    question = form('seat' => { 'type' => 'string', 'enum' => %w[window aisle] },
                    'size' => { 'type' => 'string', 'enum' => %w[s l], 'enumNames' => %w[Small] },
                    'card' => { 'type' => 'string', 'oneOf' => cards },
                    'tags' => { 'type' => 'array', 'items' => { 'type' => 'string', 'enum' => %w[a b] } })

    expect(question.fields.map(&:choice_titles))
      .to eq([{ 'window' => 'window', 'aisle' => 'aisle' }, { 's' => 'Small', 'l' => 'l' },
              { '17' => 'bank', '42' => '42' }, { 'a' => 'a', 'b' => 'b' }])
  end

  it 'keeps choices apart that share a title' do
    banks = [{ 'const' => '17', 'title' => 'bank' }, { 'const' => '42', 'title' => 'bank' }]
    question = form('card' => { 'type' => 'string', 'oneOf' => banks })

    expect(question.fields.first.choice_titles).to eq('17' => 'bank', '42' => 'bank')
  end

  it 'gives no choice titles for a field without choices' do
    question = form('name' => { 'type' => 'string' })

    expect(question.fields.first).to have_attributes(choices: nil, choice_titles: nil)
  end

  it 'refuses a field the question does not ask for' do
    question = form('name' => { 'type' => 'string' })

    expect { question.answer(name: 'Ada', age: 36) }.to raise_error(ArgumentError, /does not ask for age/)
  end

  it 'refuses a choice the field does not offer, one by one in a multi-select' do
    question = form('colors' => { 'type' => 'array', 'items' => { 'type' => 'string', 'enum' => %w[red green] } })

    expect { question.answer(colors: %w[red blue]) }.to raise_error(ArgumentError, /"blue" is not one of the choices/)
  end

  it 'needs the required fields, and counts a blank one as left out' do
    question = form({ 'name' => { 'type' => 'string', 'title' => 'Name' } }, ['name'])

    expect { question.answer(name: ' ') }.to raise_error(ArgumentError, /Name needs an answer/)
    expect(question).not_to be_answered
  end

  it 'lists the choices of a multi-select field without titles' do
    question = form('colors' => { 'type' => 'array', 'items' => { 'type' => 'string', 'enum' => %w[red green blue] } })

    expect(question.fields.first.choices).to eq(%w[red green blue])
  end

  it 'keeps the fields it asks for of the parameters a form sends' do
    question = form({ 'name' => { 'type' => 'string' }, 'age' => { 'type' => 'integer' },
                      'tags' => { 'type' => 'array' } }, %w[name])

    question.answer(ActionController::Parameters.new(name: 'Ada', age: '36', tags: %w[math], admin: 'true'))

    expect(question.response)
      .to eq('action' => 'accept', 'content' => { 'name' => 'Ada', 'age' => 36, 'tags' => %w[math] })
  end

  it 'accepts a page to visit without content, and refuses a value for it' do
    question = described_class.new('connect', { 'mode' => 'url', 'url' => 'https://example.com/connect' })

    expect { question.answer('done') }.to raise_error(ArgumentError, /takes no answer/)

    question.answer('  ')

    expect(question.response).to eq('action' => 'accept')
    expect(question).not_to be_form
  end

  it 'declines' do
    question = form('name' => { 'type' => 'string' })

    question.decline

    expect(question.response).to eq('action' => 'decline')
  end

  it 'leaves approving to approvals' do
    question = form('name' => { 'type' => 'string' })

    expect { question.approve }.to raise_error(ArgumentError, /answer it instead/)
  end

  it 'keeps the note it was declined with, and takes a blank note as none' do
    expect(form('name' => { 'type' => 'string' }).decline('Not now').response)
      .to eq('action' => 'decline', 'note' => 'Not now')
    expect(form('name' => { 'type' => 'string' }).decline(" \n").response).to eq('action' => 'decline')
  end

  it 'keeps a Hash it was declined with, and takes an empty Hash as none' do
    expect(form('name' => { 'type' => 'string' }).decline(error: 'Denied').response)
      .to eq('action' => 'decline', 'note' => { error: 'Denied' })
    expect(form('name' => { 'type' => 'string' }).decline({}).response).to eq('action' => 'decline')
  end

  it 'reads in one line' do
    question = form('name' => { 'type' => 'string' })

    expect(question.inspect).to match(/\A#<RubyLLM::Question id: "\h+", message: "Your profile", fields: \[:name\]>\z/)
  end
end
