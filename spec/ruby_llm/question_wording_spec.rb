# frozen_string_literal: true

require 'spec_helper'

# What an app shows a person under a form when their answer can't be taken.
RSpec.describe RubyLLM::Question do
  def form(properties, required = [])
    described_class.new('profile', { 'message' => 'Your profile',
                                     'requestedSchema' => { 'properties' => properties, 'required' => required } })
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
end
