# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::WebSource do
  let(:responses_output) do
    [
      { 'type' => 'web_search_call', 'id' => 'ws_1', 'status' => 'completed',
        'action' => {
          'type' => 'search', 'queries' => ['latest stable Ruby version'],
          'sources' => [{ 'type' => 'url', 'url' => 'https://www.ruby-lang.org/en/downloads/branches/' },
                        { 'type' => 'url', 'url' => 'https://www.ruby-lang.org/en/downloads/releases/' }]
        } },
      { 'type' => 'web_search_call', 'id' => 'ws_2', 'status' => 'completed',
        'action' => { 'type' => 'find_in_page', 'pattern' => 'Ruby 4.0.9',
                      'url' => 'https://www.ruby-lang.org/en/downloads/releases/' } },
      { 'type' => 'web_search_call', 'id' => 'ws_3', 'status' => 'completed',
        'action' => { 'type' => 'open_page', 'url' => 'https://www.ruby-lang.org/en/downloads/' } }
    ]
  end
  let(:anthropic_result) do
    { 'type' => 'web_search_tool_result', 'tool_use_id' => 'srvtoolu_01Fgr1Y563cyQA4J8rajNpwW',
      'content' => [{ 'type' => 'web_search_result', 'title' => 'Ruby 4.0.5 Released',
                      'url' => 'https://www.ruby-lang.org/en/news/2026/05/20/ruby-4-0-5-released/',
                      'encrypted_content' => 'EqgfCioI', 'page_age' => '144 days ago' }],
      'caller' => { 'type' => 'direct' } }
  end
  let(:gemini_response) do
    { 'candidates' => [{ 'groundingMetadata' => {
      'webSearchQueries' => ['latest stable Ruby version'],
      'groundingChunks' => [{ 'web' => {
        'uri' => 'https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZIYQED75BOKbi',
        'title' => 'ruby-lang.org'
      } }]
    } }] }
  end

  def message_from(provider, server_tool_calls)
    RubyLLM::Message.new(role: :assistant, content: 'Done', provider:, server_tool_calls:)
  end

  def responses_message(provider = 'openai')
    message_from(provider, RubyLLM::Protocols::Responses::Chat.parse_server_tool_items(responses_output))
  end

  describe 'Message#web_sources' do
    %w[openai azure meta xai].each do |provider|
      it "lists what a #{provider} search found and opened, each address once" do
        expect(responses_message(provider).web_sources.map(&:url)).to eq(
          %w[https://www.ruby-lang.org/en/downloads/branches/
             https://www.ruby-lang.org/en/downloads/releases/
             https://www.ruby-lang.org/en/downloads/]
        )
      end
    end

    it 'gives no title where the Responses API reports none' do
      expect(responses_message.web_sources.map(&:title)).to all(be_nil)
    end

    it 'lists the results of an Anthropic search with their titles' do
      calls = RubyLLM::Protocols::Anthropic::Chat.parse_server_tool_calls([anthropic_result])

      expect(message_from('anthropic', calls).web_sources.map(&:to_h)).to eq(
        [{ url: 'https://www.ruby-lang.org/en/news/2026/05/20/ruby-4-0-5-released/', title: 'Ruby 4.0.5 Released' }]
      )
    end

    it 'lists nothing for an Anthropic search that failed' do
      failed = anthropic_result.merge('content' => { 'type' => 'web_search_tool_result_error',
                                                     'error_code' => 'max_uses_exceeded' })
      calls = RubyLLM::Protocols::Anthropic::Chat.parse_server_tool_calls([failed])

      expect(message_from('anthropic', calls).web_sources).to eq([])
    end

    %w[gemini vertexai].each do |provider|
      it "lists the web pages grounding a #{provider} answer" do
        calls = RubyLLM::Protocols::Gemini.allocate.send(:metadata_server_tool_calls, gemini_response)

        expect(message_from(provider, calls).web_sources.map(&:to_h)).to eq(
          [{ url: 'https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZIYQED75BOKbi',
             title: 'ruby-lang.org' }]
        )
      end
    end

    it 'leaves out document chunks that ground a Gemini answer' do
      gemini_response.dig('candidates', 0, 'groundingMetadata', 'groundingChunks') << {
        'retrievedContext' => { 'uri' => 'fileSearchStores/store/documents/doc', 'title' => 'doc.pdf' }
      }
      calls = RubyLLM::Protocols::Gemini.allocate.send(:metadata_server_tool_calls, gemini_response)

      expect(message_from('gemini', calls).web_sources.map(&:title)).to eq(['ruby-lang.org'])
    end

    it 'keeps a Gemini search with no web pages out of the sources' do
      gemini_response.dig('candidates', 0, 'groundingMetadata').delete('groundingChunks')
      calls = RubyLLM::Protocols::Gemini.allocate.send(:metadata_server_tool_calls, gemini_response)

      expect(calls.first.result).to be_nil
      expect(message_from('gemini', calls).web_sources).to eq([])
    end

    it 'does not read sources from a provider that reports none' do
      call = RubyLLM::ServerToolCall.new(type: 'web_search', raw: { 'type' => 'web_search' })

      expect(message_from('mistral', [call]).web_sources).to eq([])
    end

    it 'lists nothing for a message without a provider or a search' do
      expect(responses_message(nil).web_sources).to eq([])
      expect(message_from('openai', []).web_sources).to eq([])
    end

    it 'answers the same after the message is rebuilt from its Hash' do
      message = responses_message
      stored = JSON.parse(JSON.generate(message.to_h)).transform_keys(&:to_sym)

      expect(RubyLLM::Message.new(stored).web_sources.map(&:url)).to eq(message.web_sources.map(&:url))
    end
  end

  it 'serializes without a missing title' do
    expect(described_class.new(url: 'https://www.ruby-lang.org').to_h).to eq(url: 'https://www.ruby-lang.org')
  end

  it 'inspects on one line' do
    source = described_class.new(url: 'https://www.ruby-lang.org', title: 'Ruby')

    expect(source.inspect).to eq('#<RubyLLM::WebSource url: "https://www.ruby-lang.org", title: "Ruby">')
  end
end
