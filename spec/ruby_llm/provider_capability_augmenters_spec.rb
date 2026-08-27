# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Provider, '.capability augmenters' do
  def augment(provider, capabilities, model_id: 'test', input: ['text'], output: ['text'])
    provider.capabilities.augment(capabilities, model_id: model_id, modalities: { input: input, output: output })
  end

  it 'adds tool controls only when the catalog reports function calling' do
    expect(augment(RubyLLM::Providers::OpenAI, ['function_calling'])).to contain_exactly(
      'function_calling', 'tool_choice', 'parallel_tool_calls'
    )
    expect(augment(RubyLLM::Providers::OpenAI, [])).to be_empty
  end

  it 'keeps provider-specific tool controls narrow' do
    expect(augment(RubyLLM::Providers::DeepSeek, ['function_calling'])).to contain_exactly(
      'function_calling', 'tool_choice'
    )
    expect(augment(RubyLLM::Providers::Anthropic, ['function_calling'])).to contain_exactly(
      'function_calling', 'tool_choice', 'parallel_tool_calls'
    )
  end

  it 'recognizes only explicit OpenAI transcription model ids' do
    expect(
      augment(RubyLLM::Providers::OpenAI, [], model_id: 'gpt-4o-transcribe', input: ['audio'])
    ).to include('transcription')
    expect(
      augment(RubyLLM::Providers::OpenAI, [], model_id: 'future-transcribe', input: ['audio'])
    ).not_to include('transcription')
  end

  it 'uses Google modality facts without classifying embedding operations as transcription' do
    expect(
      augment(RubyLLM::Providers::Gemini, [], model_id: 'gemini-test', input: ['audio'])
    ).to include('transcription')
    expect(
      augment(RubyLLM::Providers::Gemini, [], model_id: 'gemini-embedding-test', input: ['audio'])
    ).not_to include('transcription')
  end
end
