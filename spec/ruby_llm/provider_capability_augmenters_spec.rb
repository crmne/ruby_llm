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
      augment(RubyLLM::Providers::OpenAI, [], model_id: 'gpt-transcribe')
    ).to include('transcription')
    expect(
      augment(RubyLLM::Providers::OpenAI, [], model_id: 'future-transcribe', input: ['audio'])
    ).not_to include('transcription')
  end

  it 'recognizes only explicit OpenAI search model ids as citable' do
    expect(
      augment(RubyLLM::Providers::OpenAI, [], model_id: 'gpt-5-search-api')
    ).to contain_exactly('structured_output', 'citations')
    expect(
      augment(RubyLLM::Providers::OpenAI, [], model_id: 'future-search')
    ).not_to include('citations')
  end

  it 'restores documented capabilities for exact OpenAI Chat and Codex model ids' do
    expect(
      augment(RubyLLM::Providers::OpenAI, [], model_id: 'gpt-5-chat-latest')
    ).to contain_exactly('function_calling', 'tool_choice', 'parallel_tool_calls', 'structured_output', 'vision')
    expect(
      augment(RubyLLM::Providers::OpenAI, [], model_id: 'gpt-5.2-codex')
    ).to include('function_calling', 'structured_output', 'vision', 'reasoning')
  end

  it 'restores documented capabilities for exact OpenAI research and moderation model ids' do
    expect(
      augment(RubyLLM::Providers::OpenAI, [], model_id: 'o3-deep-research')
    ).to contain_exactly('vision', 'reasoning')
    expect(
      augment(RubyLLM::Providers::OpenAI, [], model_id: 'omni-moderation-latest')
    ).to contain_exactly('vision')
  end

  it 'adds streaming to xAI models with text output' do
    expect(augment(RubyLLM::Providers::XAI, [])).to include('streaming')
    expect(
      augment(RubyLLM::Providers::XAI, [], output: ['image'])
    ).not_to include('streaming')
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
