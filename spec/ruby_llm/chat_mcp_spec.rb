# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat, :live do
  describe 'remote MCP tools' do
    TEST_MODELS.fetch(:mcp).select { |model_info| model_info.fetch(:approval) }.each do |model_info|
      provider = model_info.fetch(:provider)

      context provider.to_s do
        let(:chat) do
          RubyLLM.chat(model: model_for(provider, :mcp), provider:, protocol: model_info.fetch(:protocol))
                 .with_server_tools(mcp: {
                                      name: 'docs', url: 'https://learn.microsoft.com/api/mcp',
                                      allowed_tools: ['microsoft_docs_search'], require_approval: 'always'
                                    })
                 .with_instructions(
                   'Use microsoft_docs_search exactly once when asked for documentation. Do not retry a denied call.'
                 )
        end

        def request_documentation(&block)
          chat.ask('Search Microsoft documentation for Azure Blob Storage, then give one short sentence about it.',
                   &block)
        end

        it 'executes a remote read-only tool after approval using stateless continuation' do
          request_documentation

          expect(chat).to be_awaiting_approval
          expect(chat.pending_approvals.size).to eq(1)
          expect(chat.pending_approvals.first).to have_attributes(remote?: true, name: 'microsoft_docs_search')

          chat.approve(chat.pending_approvals.first)
          response = chat.complete

          expect(chat).to be_complete
          expect(response.server_tool_calls).to include(have_attributes(type: 'mcp_call', name: 'microsoft_docs_search',
                                                                        result: a_kind_of(String)))
          expect(response.content).to match(/blob/i)
        end

        it 'denies a remote call without executing it' do
          request_documentation
          expect(chat).to be_awaiting_approval
          chat.deny(chat.pending_approvals.first)

          chat.complete

          expect(chat).to be_complete
          expect(chat.messages.flat_map(&:server_tool_calls)).not_to include(have_attributes(type: 'mcp_call'))
          expect(chat.messages.find(&:tool_result?).raw_content.first[:approve]).to be(false)
        end

        it 'streams a remote approval and its completed result' do
          chunks = []
          request_documentation { |chunk| chunks << chunk }
          expect(chat.pending_approvals.size).to eq(1)
          expect(chat.pending_approvals.first).to be_remote
          chat.approve(chat.pending_approvals.first)

          response = chat.complete { |chunk| chunks << chunk }

          expect(chat).to be_complete
          expect(response.server_tool_calls).to include(have_attributes(type: 'mcp_call',
                                                                        name: 'microsoft_docs_search'))
          expect(chunks.filter_map(&:content).join).to match(/blob/i)
        end
      end
    end
  end

  describe 'remote MCP execution' do
    %i[anthropic xai].each do |provider|
      it "#{provider} executes a read-only tool and replays its history" do
        options = { name: 'docs', url: 'https://learn.microsoft.com/api/mcp' }
        if provider == :anthropic
          options[:default_config] = { enabled: false }
          options[:configs] = { microsoft_docs_search: { enabled: true } }
        end
        options[:allowed_tools] = ['microsoft_docs_search'] if provider == :xai
        chat = RubyLLM.chat(model: model_for(provider), provider:)
                      .with_server_tools(mcp: options)
                      .with_instructions(
                        'Call microsoft_docs_search once to answer the first question. ' \
                        'For later questions use only those results.'
                      )

        response = chat.ask('Search Microsoft documentation for Azure Blob Storage, then summarize it in one sentence.')
        calls = response.server_tool_calls

        expect(chat).to be_complete
        expect(chat.pending_approvals).to be_empty
        expect(calls).to include(have_attributes(name: a_string_including('microsoft_docs_search')))
        expect(calls.filter_map(&:result)).not_to be_empty
        expect(response.content).to match(/blob/i)
        expect(chat.ask('Which cloud service did you just look up?').content).to match(/blob/i)
      end
    end
  end
end
