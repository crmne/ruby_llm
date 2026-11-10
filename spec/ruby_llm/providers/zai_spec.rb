# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::ZAI do
  subject(:provider) { described_class.new(config) }

  let(:config) do
    RubyLLM::Configuration.new.tap do |provider_config|
      provider_config.zai_api_key = 'test-key'
    end
  end
  let(:model_id) { model_for(:zai) }
  let(:completions_url) { 'https://api.z.ai/api/paas/v4/chat/completions' }

  def context
    RubyLLM.context { |context_config| context_config.zai_api_key = 'test-key' }
  end

  def stub_completion(message: { role: 'assistant', content: 'Hi' }, finish_reason: 'stop', usage: nil)
    stub_request(:post, completions_url)
      .with(headers: { 'Authorization' => 'Bearer test-key' })
      .to_return(status: 200, body: {
        id: 'chatcmpl-1', object: 'chat.completion', model: model_id,
        choices: [{ index: 0, message: message, finish_reason: finish_reason }],
        usage: usage || { prompt_tokens: 12, completion_tokens: 3, total_tokens: 15 }
      }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def sent_body
    body = nil
    expect(a_request(:post, completions_url).with { |request| body = JSON.parse(request.body) }).to have_been_made
    body
  end

  it "speaks Z.ai's dialect of Chat Completions" do
    expect(described_class.protocols).to eq(chat_completions: described_class::ChatCompletions,
                                            files: RubyLLM::Protocols::ZAI::Files)
    expect(described_class::ChatCompletions.superclass).to eq(RubyLLM::Protocols::ChatCompletions)
  end

  it 'declares provider configuration' do
    expect(described_class.configuration_options).to eq(%i[zai_api_key zai_api_base])
    expect(described_class.configuration_requirements).to eq(%i[zai_api_key])
  end

  it 'defaults to the international Z.ai endpoint and sends a bearer token' do
    expect(provider.api_base).to eq('https://api.z.ai/api/paas/v4')
    expect(provider.headers).to eq('Authorization' => 'Bearer test-key')
  end

  it 'talks to BigModel when configured with its endpoint' do
    config.zai_api_base = 'https://open.bigmodel.cn/api/paas/v4'

    expect(provider.api_base).to eq('https://open.bigmodel.cn/api/paas/v4')
  end

  it 'is a remote provider that requires an API key' do
    expect(described_class).not_to be_local
    expect(RubyLLM::Provider.providers).to include(zai: described_class)
    expect(described_class).to be_remote
    expect(described_class.configured?(RubyLLM::Configuration.new)).to be(false)
    expect(described_class.configured?(config)).to be(true)
  end

  it 'reads the models.dev zai catalog' do
    expect(described_class.models_dev_provider_ids).to eq(%w[zai])
    expect(RubyLLM.models.find(model_id, provider: :zai).context_window).to eq(1_000_000)
  end

  describe 'chat' do
    it 'sends instructions with the system role and the end user as user_id' do
      stub_completion

      context.chat(model: model_id, provider: :zai)
             .with_instructions('Answer in German.')
             .with_end_user('user-42')
             .ask('Hello')

      expect(sent_body).to include(
        'messages' => [{ 'role' => 'system', 'content' => 'Answer in German.' },
                       { 'role' => 'user', 'content' => 'Hello' }],
        'user_id' => 'user-42'
      )
    end

    it 'parses reasoning and counts cached input' do
      stub_completion(
        message: { role: 'assistant', content: '391', reasoning_content: '17 times 23 is 391.' },
        usage: { prompt_tokens: 100, completion_tokens: 30, total_tokens: 130,
                 prompt_tokens_details: { cached_tokens: 80 } }
      )

      response = context.chat(model: model_id, provider: :zai).ask('What is 17*23?')

      expect(response.content).to eq('391')
      expect(response.thinking.text).to eq('17 times 23 is 391.')
      expect(response.tokens.input).to eq(20)
      expect(response.tokens.cache_read).to eq(80)
    end

    it 'names a blocked answer as filtered content' do
      stub_completion(finish_reason: 'sensitive')

      response = context.chat(model: model_id, provider: :zai).ask('Hello')

      expect(response.finish_reason).to eq(:content_filter)
    end

    it 'asks for thinking with an effort' do
      stub_completion

      context.chat(model: model_id, provider: :zai).with_thinking(effort: :high).ask('Hello')

      expect(sent_body).to include('thinking' => { 'type' => 'enabled' }, 'reasoning_effort' => 'high')
    end

    it 'turns thinking off on models with a toggle' do
      stub_completion

      context.chat(model: 'glm-4.7', provider: :zai).with_thinking(false).ask('Hello')

      expect(sent_body['thinking']).to eq('type' => 'disabled')
      expect(sent_body).not_to have_key('reasoning_effort')
    end

    it 'sends earlier reasoning back as reasoning_content' do
      stub_completion
      chat = context.chat(model: model_id, provider: :zai)
      chat.add_message(role: :user, content: 'What is 17*23?')
      chat.add_message(role: :assistant, content: '391', thinking: RubyLLM::Thinking.build(text: 'Multiply.'))

      chat.ask('And 17*24?')

      expect(sent_body['messages'][1]).to eq('role' => 'assistant', 'content' => '391',
                                             'reasoning_content' => 'Multiply.')
    end

    it 'sends no prompt cache controls' do
      stub_completion

      context.chat(model: model_id, provider: :zai).with_caching(key: 'docs').ask('Hello')

      expect(sent_body.keys).not_to include('prompt_cache_key', 'prompt_cache_options')
    end
  end

  describe 'calls: :one' do
    def lookup_tool
      stub_const('LookupTool', Class.new(RubyLLM::Tool) do
        description 'Looks something up'

        def execute = 'found'
      end)
    end

    it 'raises before sending, because the API ignores parallel_tool_calls' do
      chat = context.chat(model: model_id, provider: :zai).with_tools(lookup_tool).with_tool_options(calls: :one)

      expect { chat.ask('Look it up') }.to raise_error(ArgumentError, 'Z.ai does not accept calls: :one')
      expect(a_request(:post, completions_url)).not_to have_been_made
    end

    it 'does nothing on a request without tools' do
      stub_completion

      context.chat(model: model_id, provider: :zai).with_tool_options(calls: :one).ask('Hello')

      expect(sent_body).not_to include('parallel_tool_calls')
    end

    it 'allows calls: :many, leaving the undocumented field off the wire' do
      stub_completion

      context.chat(model: model_id, provider: :zai)
             .with_tools(lookup_tool).with_tool_options(calls: :many).ask('Hello')

      expect(sent_body).to include('tools')
      expect(sent_body).not_to include('parallel_tool_calls')
    end
  end

  describe 'attachments' do
    let(:protocol) { described_class::Chat }

    it 'sends images as image_url parts' do
      image = RubyLLM::Attachment.new('https://example.com/ruby.png')

      content = protocol.render_content('What is this?', [image])

      expect(content.last).to eq(type: 'image_url', image_url: { url: 'https://example.com/ruby.png' })
    end

    it 'sends uploaded files by id' do
      upload = RubyLLM::Attachment.new(RubyLLM::UploadedFile.new(id: 'file-1', provider: 'zai', filename: 'a.pdf'))

      expect(protocol.supported_attachment?(upload)).to be(true)
      expect(protocol.render_content('Read this', [upload]).last).to eq(type: 'file', file: { file_id: 'file-1' })
    end

    it 'refuses files uploaded elsewhere and uploaded audio' do
      foreign = RubyLLM::Attachment.new(RubyLLM::UploadedFile.new(id: 'file-2', provider: 'openai', filename: 'a.pdf'))
      audio = RubyLLM::Attachment.new(RubyLLM::UploadedFile.new(id: 'file-3', provider: 'zai', filename: 'a.mp3'))

      expect(protocol.supported_attachment?(foreign)).to be(false)
      expect(protocol.supported_attachment?(audio)).to be(false)
    end

    it 'refuses audio' do
      audio = RubyLLM::Attachment.new(File.expand_path('../../fixtures/ruby.wav', __dir__))

      expect(protocol.supported_attachment?(audio)).to be(false)
    end

    context 'with an inline PDF' do
      let(:chat_url) { 'https://api.z.ai/api/paas/v4/chat/completions' }

      def pdf_path = File.expand_path('../../fixtures/sample.pdf', __dir__)

      before do
        stub_request(:post, 'https://api.z.ai/api/paas/v4/files').to_return(
          status: 200,
          body: { id: 'file-9', object: 'file', filename: 'sample.pdf', purpose: 'user_data', bytes: 3 }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
        stub_request(:post, chat_url).to_return(
          status: 200,
          body: { id: 'c', model: 'm', usage: { prompt_tokens: 1, completion_tokens: 1 },
                  choices: [{ index: 0, finish_reason: 'stop', message: { role: 'assistant', content: 'ok' } }] }
                .to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
      end

      def zai_context(auto_upload: true)
        RubyLLM.context do |config|
          config.zai_api_key = 'test'
          config.auto_upload_large_files = auto_upload
        end
      end

      it 'uploads it and sends the file id' do
        zai_context.chat(model: 'glm-5.3-flash', provider: :zai).ask('Read', with: pdf_path)

        expect(a_request(:post, chat_url).with do |request|
          JSON.parse(request.body).dig('messages', 0, 'content').include?(
            { 'type' => 'file', 'file' => { 'file_id' => 'file-9' } }
          )
        end).to have_been_made
      end

      it 'raises on a model that cannot read a file id' do
        chat = zai_context.chat(model: 'glm-5.2', provider: :zai, assume_model_exists: true)

        expect { chat.ask('Read', with: pdf_path) }.to raise_error(RubyLLM::UnsupportedAttachmentError)
        expect(a_request(:post, 'https://api.z.ai/api/paas/v4/files')).not_to have_been_made
      end

      it 'raises when automatic upload is off' do
        chat = zai_context(auto_upload: false).chat(model: 'glm-5.3-flash', provider: :zai)

        expect { chat.ask('Read', with: pdf_path) }.to raise_error(RubyLLM::UnsupportedAttachmentError)
      end
    end

    it 'sends a PDF URL through on the series that reads files, and refuses it elsewhere' do
      flash = described_class::ChatCompletions.new(provider, RubyLLM::Model.default('glm-5.3-flash', 'zai'))
      other = described_class::ChatCompletions.new(provider, RubyLLM::Model.default('glm-5.2', 'zai'))
      pdf = RubyLLM::Attachment.new('https://example.com/a.pdf')

      expect(flash.send(:render_content, 'Read', [pdf]).last)
        .to eq(type: 'file', file: { file_url: 'https://example.com/a.pdf' })
      expect(other.send(:supported_attachment?, pdf)).to be(false)
    end

    it 'sends videos by URL or as data URIs' do
      remote = RubyLLM::Attachment.new('https://example.com/clip.mp4', mime_type: 'video/mp4')
      local = RubyLLM::Attachment.new(File.expand_path('../../fixtures/ruby_clip.mp4', __dir__))

      expect(protocol.render_content('Watch this', [remote, local]).drop(1)).to eq(
        [
          { type: 'video_url', video_url: { url: 'https://example.com/clip.mp4' } },
          { type: 'video_url', video_url: { url: local.for_llm } }
        ]
      )
    end

    it 'rejects documents and audio' do
      pdf = RubyLLM::Attachment.new(File.expand_path('../../fixtures/sample.pdf', __dir__))
      audio = RubyLLM::Attachment.new(File.expand_path('../../fixtures/ruby.wav', __dir__))

      expect { protocol.render_content('Read this', [pdf]) }.to raise_error(RubyLLM::UnsupportedAttachmentError)
      expect { protocol.render_content('Hear this', [audio]) }.to raise_error(RubyLLM::UnsupportedAttachmentError)
    end
  end

  describe 'web search citations' do
    def citations_for(extra)
      body = { choices: [{ message: { role: 'assistant', content: 'Hi' }, finish_reason: 'stop' }] }.merge(extra)
      stub_request(:post, completions_url)
        .to_return(status: 200, body: body.to_json, headers: { 'Content-Type' => 'application/json' })
      context.chat(model: model_id, provider: :zai).ask('Hi').citations
    end

    it 'builds citations from the web_search array, skipping malformed entries' do
      citations = citations_for(web_search: ['bad', { link: 'https://a.test', title: 'A', content: 'text' }])

      expect(citations.map(&:to_h)).to contain_exactly(
        include(url: 'https://a.test', title: 'A', cited_text: 'text', source_index: 1)
      )
    end

    it 'has no citations without the array' do
      expect(citations_for({})).to eq([])
    end
  end
end
