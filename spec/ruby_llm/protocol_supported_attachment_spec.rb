# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocol, '#supported_attachment?' do
  include_context 'with configured RubyLLM'

  protocols = [
    [RubyLLM::Protocols::Anthropic, :anthropic, %w[png pdf txt]],
    [RubyLLM::Protocols::ChatCompletions, :openai, %w[png wav pdf txt]],
    [RubyLLM::Protocols::Responses, :openai, %w[png pdf docx pptx txt]],
    [RubyLLM::Protocols::Gemini, :gemini, %w[png wav mov pdf txt]],
    [RubyLLM::Protocols::Converse, :bedrock, %w[png wav mov pdf docx txt]],
    [RubyLLM::Protocols::Cohere, :cohere, %w[png txt]],
    [RubyLLM::Protocols::Interactions, :gemini, %w[png wav mov pdf txt]],
    [RubyLLM::Providers::Azure::ChatCompletions, :azure, %w[png wav txt]],
    [RubyLLM::Providers::GPUStack::ChatCompletions, :gpustack, %w[png wav mov txt]],
    [RubyLLM::Providers::Mistral::ChatCompletions, :mistral, %w[png wav pdf docx pptx txt]],
    [RubyLLM::Providers::Mistral::Conversations, :mistral, %w[png wav pdf docx pptx txt]],
    [RubyLLM::Providers::Ollama::ChatCompletions, :ollama, %w[png wav txt]],
    [RubyLLM::Providers::OpenRouter::ChatCompletions, :openrouter, %w[png wav mov pdf txt]],
    [RubyLLM::Providers::Perplexity::ChatCompletions, :perplexity, %w[png pdf docx pptx txt]],
    [RubyLLM::Protocols::Perplexity::Agent, :perplexity, %w[png txt]],
    [RubyLLM::Providers::DeepSeek::ChatCompletions, :deepseek, %w[png txt]],
    [RubyLLM::Providers::DeepSeek::Responses, :deepseek, %w[png txt]],
    [RubyLLM::Providers::Hetzner::ChatCompletions, :hetzner, %w[png txt]],
    [RubyLLM::Providers::XAI::ChatCompletions, :xai, %w[png txt]]
  ]

  protocols.each do |protocol_class, provider_name, supported_extensions|
    context protocol_class.name do
      let(:provider) { RubyLLM::Provider.providers.fetch(provider_name).new(RubyLLM.config) }
      let(:protocol) { protocol_class.new(provider) }

      %w[png wav mov pdf docx pptx txt bin].each do |extension|
        it "matches rendering support for #{extension} attachments" do
          attachment = RubyLLM::Attachment.new(StringIO.new('file bytes'), filename: "sample.#{extension}")
          supported = supported_extensions.include?(extension)
          expect(protocol.send(:supported_attachment?, attachment)).to eq(supported)
          render = lambda do
            if protocol.is_a?(RubyLLM::Protocols::Interactions)
              protocol.send(:render_interaction_attachment, attachment)
            else
              protocol.send(:format_content, 'Read this.', [attachment])
            end
          end

          if supported
            expect(render.call).not_to be_nil
          else
            error = protocol.is_a?(RubyLLM::Protocols::Interactions) ? ArgumentError : RubyLLM::UnsupportedAttachmentError
            expect(&render).to raise_error(error)
          end
        end
      end
    end
  end
end
