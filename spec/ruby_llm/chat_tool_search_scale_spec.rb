# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:themes) do
    %w[
      weather stock translate calculator dictionary news sports currency
      flight hotel restaurant movie book recipe article code git docker
      kubernetes aws gcp azure sql redis postgres mongo kafka rabbitmq
      elastic prometheus grafana jira github slack teams zoom gmail
      calendar drive notion linear pagerduty datadog
    ]
  end
  let(:tool_classes) do
    themes.map.with_index do |theme, i|
      klass = build_tool_class(theme)
      stub_const("ScaleTool#{i}", klass)
      klass
    end
  end
  let(:chat_anthropic) do
    RubyLLM.chat(model: 'claude-haiku-4-5', provider: :anthropic).tap do |c|
      c.with_tools(*tool_classes, defer: true)
    end
  end

  def build_tool_class(theme)
    Class.new(RubyLLM::Tool) do
      description "Looks up #{theme} information for a given query."
      param :query, desc: "Input for the #{theme} lookup"

      # Override #name so the tool registers under its theme, independent of
      # the auto-generated class-name derivation. Keeps assertions readable.
      define_method(:name) { theme }
      define_method(:execute) { |query:| "#{theme}: #{query}" }
    end
  end

  describe 'Anthropic deferred tool loading at scale (40+ tools)' do
    it 'registers 40+ deferred tools in the catalog without error' do
      expect(tool_classes.size).to be >= 40
      expect(chat_anthropic.tool_catalog.deferred_tools.size).to eq(tool_classes.size)
      expect(chat_anthropic.tools).to be_empty
    end

    it 'flags every deferred tool with defer_loading: true and appends the native primitive exactly once' do
      payload = RubyLLM::Providers::Anthropic::Chat.render_payload(
        [RubyLLM::Message.new(role: :user, content: 'hi')],
        tools: chat_anthropic.send(:effective_tools),
        temperature: nil,
        model: chat_anthropic.model,
        stream: false
      )

      entries = payload[:tools]
      deferred = entries.select { |t| t[:defer_loading] == true }
      expect(deferred.size).to eq(tool_classes.size)

      native = entries.select { |t| t[:type] == 'tool_search_tool_bm25_20251119' }
      expect(native.size).to eq(1)
      expect(native.first[:name]).to eq('tool_search_tool_bm25')
    end

    it 'promotes deferred tools when the native path surfaces tool_references' do
      referenced = %w[flight hotel restaurant]
      message = RubyLLM::Message.new(role: :assistant, content: '', tool_references: referenced)

      chat_anthropic.send(:promote_from_tool_references, message)

      expect(chat_anthropic.tool_catalog.loaded_tools).to match_array(referenced.map(&:to_sym))
      referenced.each do |name|
        expect(chat_anthropic.tools.keys).to include(name.to_sym)
      end
    end
  end
end
