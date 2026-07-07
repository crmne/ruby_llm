# frozen_string_literal: true

require 'spec_helper'

# Each provider operation is served by a trio of wire seams the Protocol base
# leaves abstract: render_* serializes the request, *_url names the endpoint, and
# parse_* reads the response. A protocol must implement chat, and must implement
# every other operation it supports as a complete trio rather than a partial one,
# so a half-added operation fails at load time instead of on the first request.
RSpec.shared_examples 'a protocol' do |family|
  operations = {
    'chat' => %i[render_payload completion_url parse_completion_body],
    'model listing' => %i[models_url parse_list_models_response],
    'embeddings' => %i[render_embedding_payload embedding_url parse_embedding_response],
    'moderation' => %i[render_moderation_payload moderation_url parse_moderation_response],
    'image' => %i[render_image_payload images_url parse_image_response],
    'speech' => %i[render_speech_payload speech_url parse_speech_response],
    'transcription' => %i[render_transcription_payload transcription_url parse_transcription_response]
  }
  overridden = ->(seams) { seams.reject { |seam| family.instance_method(seam).owner == RubyLLM::Protocol } }

  it 'implements the chat seams' do
    seams = operations.fetch('chat')
    expect(overridden.call(seams)).to eq(seams)
  end

  operations.except('chat').each do |operation, seams|
    it "implements #{operation} completely or not at all" do
      done = overridden.call(seams)
      missing = seams - done
      message = "#{family} partially implements #{operation}: has #{done.join(', ')}, missing #{missing.join(', ')}"
      expect(done.empty? || missing.empty?).to be(true), message
    end
  end
end

RSpec.describe RubyLLM::Protocol do
  {
    'Chat Completions' => RubyLLM::Protocols::ChatCompletions,
    'Responses' => RubyLLM::Protocols::Responses,
    'Anthropic' => RubyLLM::Protocols::Anthropic,
    'Gemini' => RubyLLM::Protocols::Gemini,
    'Converse' => RubyLLM::Protocols::Converse
  }.each do |name, family|
    describe name do
      it_behaves_like 'a protocol', family
    end
  end
end
