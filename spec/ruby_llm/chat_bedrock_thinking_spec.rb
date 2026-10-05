# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat, :live do
  it 'uses between-tools thinking for regional Bedrock Sonnet 5.5' do
    skip_without_cassette_or_key('AWS_ACCESS_KEY_ID')
    model = RubyLLM.models.find('us.anthropic.claude-sonnet-5-5', provider: :bedrock)
    chat = RubyLLM.chat(model: model.id, provider: :bedrock).with_thinking(false).with_max_output_tokens(128)
    payload = nil
    chat.before_request { |request| payload = request }

    response = chat.ask('Reply with the single word Hello.')

    expect(payload.dig(:additionalModelRequestFields, :thinking)).to eq(type: 'between_tools')
    expect(response.content).to include('Hello')
    expect(response.tokens.output).to be_positive
  rescue RubyLLM::ForbiddenError => e
    raise unless e.message.include?('anthropic.claude-sonnet-5-5 is not available for this account')

    VCR.current_cassette.new_recorded_interactions.clear
    skip 'The configured AWS account needs AWS Sales approval for Claude Sonnet 5.5'
  end
end
