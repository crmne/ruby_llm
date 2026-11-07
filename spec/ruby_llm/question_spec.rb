# frozen_string_literal: true

require 'spec_helper'

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
  end

  it 'refuses a value that is not of the type a field asks for' do
    question = form('seats' => { 'type' => 'integer', 'title' => 'Seats' })

    expect { question.answer(seats: 'two') }.to raise_error(ArgumentError, /Seats takes a whole number/)
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

  it 'accepts a page to visit without content, and refuses a value for it' do
    question = described_class.new('connect', { 'mode' => 'url', 'url' => 'https://example.com/connect' })

    expect { question.answer('done') }.to raise_error(ArgumentError, /takes no answer/)

    question.answer

    expect(question.response).to eq('action' => 'accept')
    expect(question).not_to be_form
  end

  it 'declines' do
    question = form('name' => { 'type' => 'string' })

    question.decline

    expect(question.response).to eq('action' => 'decline')
  end

  it 'leaves approving and denying to approvals' do
    question = form('name' => { 'type' => 'string' })

    expect { question.approve }.to raise_error(ArgumentError, /answer it instead/)
    expect { question.deny }.to raise_error(ArgumentError, /decline it instead/)
  end

  it 'reads in one line' do
    question = form('name' => { 'type' => 'string' })

    expect(question.inspect).to match(/\A#<RubyLLM::Question id: "\h+", message: "Your profile", fields: \[:name\]>\z/)
  end
end
