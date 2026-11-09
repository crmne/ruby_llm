# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Moonshot do
  subject(:provider) { described_class.new(config) }

  let(:config) do
    RubyLLM::Configuration.new.tap do |provider_config|
      provider_config.moonshot_api_key = 'test-key'
    end
  end
  let(:model_id) { model_for(:moonshot) }
  let(:completions_url) { 'https://api.moonshot.ai/v1/chat/completions' }

  def context
    RubyLLM.context { |context_config| context_config.moonshot_api_key = 'test-key' }
  end

  def stub_completion(message: { role: 'assistant', content: 'Hi' }, usage: nil)
    stub_request(:post, completions_url)
      .with(headers: { 'Authorization' => 'Bearer test-key' })
      .to_return(status: 200, body: {
        id: 'chatcmpl-1', object: 'chat.completion', model: model_id,
        choices: [{ index: 0, message: message, finish_reason: 'stop' }],
        usage: usage || { prompt_tokens: 12, completion_tokens: 3, total_tokens: 15 }
      }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def sent_body
    body = nil
    expect(a_request(:post, completions_url).with { |request| body = JSON.parse(request.body) }).to have_been_made
    body
  end

  it "speaks Moonshot's dialect of Chat Completions" do
    expect(described_class.protocols[:chat_completions]).to eq(described_class::ChatCompletions)
    expect(described_class::ChatCompletions.superclass).to eq(RubyLLM::Protocols::ChatCompletions)
    expect(described_class.protocols.keys).to eq(%i[chat_completions responses files])
  end

  it 'declares provider configuration' do
    expect(described_class.configuration_options).to eq(%i[moonshot_api_key moonshot_api_base])
    expect(described_class.configuration_requirements).to eq(%i[moonshot_api_key])
  end

  it 'defaults to the international Moonshot endpoint and sends a bearer token' do
    expect(provider.api_base).to eq('https://api.moonshot.ai/v1')
    expect(provider.headers).to eq('Authorization' => 'Bearer test-key')
  end

  it 'talks to a configured endpoint instead of the default' do
    config.moonshot_api_base = 'https://api.moonshot.cn/v1'

    expect(provider.api_base).to eq('https://api.moonshot.cn/v1')
  end

  it 'is a remote provider that requires an API key' do
    expect(described_class).not_to be_local
    expect(RubyLLM::Provider.providers).to include(moonshot: described_class)
    expect(described_class).to be_remote
    expect(described_class.configured?(RubyLLM::Configuration.new)).to be(false)
    expect(described_class.configured?(config)).to be(true)
  end

  it 'reads the models.dev moonshotai catalog' do
    expect(described_class.models_dev_provider_ids).to eq(%w[moonshotai])
    expect(RubyLLM.models.find('kimi-k3', provider: :moonshot).context_window).to eq(1_048_576)
  end

  describe 'chat' do
    it 'sends instructions with the system role, the output limit, and the end user' do
      stub_completion

      context.chat(model: model_id, provider: :moonshot)
             .with_instructions('Answer in German.')
             .with_max_output_tokens(1000)
             .with_end_user('user-42')
             .ask('Hello')

      expect(sent_body).to include(
        'messages' => [{ 'role' => 'system', 'content' => 'Answer in German.' },
                       { 'role' => 'user', 'content' => 'Hello' }],
        'max_completion_tokens' => 1000,
        'safety_identifier' => 'user-42'
      )
    end

    it 'parses reasoning and counts cache reads and writes' do
      stub_completion(
        message: { role: 'assistant', content: '391', reasoning_content: '17 times 23 is 391.' },
        usage: { prompt_tokens: 100, completion_tokens: 30, total_tokens: 130, cached_tokens: 60,
                 prompt_tokens_details: { cached_tokens: 60, cache_write_tokens: 30 } }
      )

      response = context.chat(model: model_id, provider: :moonshot).ask('What is 17*23?')

      expect(response.content).to eq('391')
      expect(response.thinking.text).to eq('17 times 23 is 391.')
      expect(response.tokens.input).to eq(10)
      expect(response.tokens.cache_read).to eq(60)
      expect(response.tokens.cache_write).to eq(30)
    end

    it 'turns thinking on and off on models with a toggle' do
      stub_completion

      context.chat(model: 'kimi-k2.6', provider: :moonshot).with_thinking(false).ask('Hello')

      expect(sent_body['thinking']).to eq('type' => 'disabled')
    end

    it 'sets the effort of models that always think' do
      stub_completion

      context.chat(model: 'kimi-k3', provider: :moonshot).with_thinking(effort: :max).ask('Hello')

      expect(sent_body).to include('reasoning_effort' => 'max')
      expect(sent_body).not_to have_key('thinking')
    end

    it 'sends earlier reasoning back as reasoning_content' do
      stub_completion
      chat = context.chat(model: model_id, provider: :moonshot)
      chat.add_message(role: :user, content: 'What is 17*23?')
      chat.add_message(role: :assistant, content: '391', thinking: RubyLLM::Thinking.build(text: 'Multiply.'))

      chat.ask('And 17*24?')

      expect(sent_body['messages'][1]).to eq('role' => 'assistant', 'content' => '391',
                                             'reasoning_content' => 'Multiply.')
    end

    it 'sends a prompt cache key and lifetime without breakpoints' do
      stub_completion

      context.chat(model: model_id, provider: :moonshot).with_caching(key: 'docs', ttl: '1h').ask('Hello')

      expect(sent_body).to include('prompt_cache_key' => 'docs', 'prompt_cache_options' => { 'ttl' => '1h' })
      expect(sent_body.to_json).not_to include('prompt_cache_breakpoint')
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
      chat = context.chat(model: model_id, provider: :moonshot).with_tools(lookup_tool).with_tool_options(calls: :one)

      expect { chat.ask('Look it up') }.to raise_error(ArgumentError, 'Moonshot does not accept calls: :one')
      expect(a_request(:post, completions_url)).not_to have_been_made
    end

    it 'does nothing on a request without tools' do
      stub_completion

      context.chat(model: model_id, provider: :moonshot).with_tool_options(calls: :one).ask('Hello')

      expect(sent_body).not_to include('parallel_tool_calls')
    end

    it 'allows calls: :many, leaving the undocumented field off the wire' do
      stub_completion

      context.chat(model: model_id, provider: :moonshot)
             .with_tools(lookup_tool).with_tool_options(calls: :many).ask('Hello')

      expect(sent_body).to include('tools')
      expect(sent_body).not_to include('parallel_tool_calls')
    end
  end

  describe 'attachments' do
    let(:protocol) { described_class::Chat }

    it 'sends remote images inline, because Moonshot reads only data URIs' do
      image = RubyLLM::Attachment.new('https://example.com/ruby.png')
      stub_request(:get, 'https://example.com/ruby.png')
        .to_return(status: 200, body: 'png bytes', headers: { 'Content-Type' => 'image/png' })

      content = protocol.render_content('What is this?', [image])

      data_uri = "data:image/png;base64,#{Base64.strict_encode64('png bytes')}"
      expect(content.last).to eq(type: 'image_url', image_url: { url: data_uri })
    end

    it 'rejects documents and audio' do
      pdf = RubyLLM::Attachment.new(File.expand_path('../../fixtures/sample.pdf', __dir__))
      audio = RubyLLM::Attachment.new(File.expand_path('../../fixtures/ruby.wav', __dir__))

      expect { protocol.render_content('Read this', [pdf]) }.to raise_error(RubyLLM::UnsupportedAttachmentError)
      expect { protocol.render_content('Hear this', [audio]) }.to raise_error(RubyLLM::UnsupportedAttachmentError)
    end

    it 'refers to an uploaded image by its Moonshot file reference' do
      file = RubyLLM::UploadedFile.new(id: 'file-1', provider: 'moonshot', mime_type: 'image/png', purpose: 'image')

      content = protocol.render_content('What is this?', [RubyLLM::Attachment.new(file)])

      expect(content.last).to eq(type: 'image_url', image_url: { url: 'ms://file-1' })
    end
  end

  describe 'documents in chat' do
    let(:pdf_path) { File.expand_path('../../fixtures/sample.pdf', __dir__) }
    let(:file_url) { 'https://api.moonshot.ai/v1/files' }

    def extract_body
      { content: '# Extracted', file_type: 'application/pdf', type: 'file' }.to_json
    end

    def stub_upload(id: 'file-1')
      stub_request(:post, file_url).to_return(
        status: 200,
        body: { id:, object: 'file', bytes: 10, created_at: 1, filename: 'sample.pdf',
                purpose: 'file-extract', status: 'ok', file_type: 'application/pdf' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    end

    it 'sends the text Moonshot extracts from a PDF, uploading it once across turns' do
      stub_completion
      stub_upload
      content = stub_request(:get, "#{file_url}/file-1/content")
                .to_return(status: 200, body: extract_body, headers: { 'Content-Type' => 'application/json' })
      chat = context.chat(model: model_id, provider: :moonshot)

      chat.ask('Summarize', with: pdf_path)
      chat.ask('Again')

      expect(a_request(:post, completions_url).with { |request| request.body.include?('# Extracted') })
        .to have_been_made.twice
      expect(a_request(:post, file_url)).to have_been_made.once
      expect(content).to have_been_made.twice
      expect(chat.messages.first.attachments.first.mime_type).to eq('application/pdf')
    end

    it 'uploads again when the extracted file has gone' do
      stub_completion
      stub_upload
      stub_request(:get, "#{file_url}/file-1/content")
        .to_return({ status: 404, body: { error: { message: 'gone' } }.to_json,
                     headers: { 'Content-Type' => 'application/json' } },
                   { status: 200, body: extract_body, headers: { 'Content-Type' => 'application/json' } })
      chat = context.chat(model: model_id, provider: :moonshot)

      chat.ask('Summarize', with: pdf_path)

      expect(a_request(:post, file_url)).to have_been_made.twice
    end

    it 'reads a file already uploaded for extraction' do
      stub_completion
      stub_request(:get, "#{file_url}/file-1/content")
        .to_return(status: 200, body: extract_body, headers: { 'Content-Type' => 'application/json' })
      file = RubyLLM::UploadedFile.new(id: 'file-1', provider: 'moonshot', filename: 'a.pdf',
                                       mime_type: 'application/pdf', purpose: 'file-extract')

      context.chat(model: model_id, provider: :moonshot).ask('Summarize', with: file)

      expect(sent_body['messages'].first['content'].last['text']).to include('# Extracted')
    end

    it 'extracts a document for OCR and removes the upload' do
      stub_upload
      stub_request(:get, "#{file_url}/file-1/content")
        .to_return(status: 200, body: extract_body, headers: { 'Content-Type' => 'application/json' })
      delete = stub_request(:delete, "#{file_url}/file-1").to_return(status: 200, body: '{}')

      ocr = context.ocr(pdf_path, model: model_id, provider: :moonshot)

      expect(ocr.markdown).to eq('# Extracted')
      expect(ocr.model).to eq(model_id)
      expect(delete).to have_been_made
    end

    it 'refuses page selection for OCR' do
      expect { context.ocr(pdf_path, model: model_id, provider: :moonshot, pages: [0]) }
        .to raise_error(ArgumentError, /pages/)
    end
  end

  describe 'files' do
    def uploaded_purpose(file)
      body = nil
      stub_request(:post, 'https://api.moonshot.ai/v1/files')
        .with { |request| body = request.body }
        .to_return(status: 200, body: { id: 'f', bytes: 1, created_at: 1, filename: 'x', purpose: 'p' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })
      provider.upload_file(file)
      body[/name="purpose"\r\n\r\n([^\r]+)/, 1]
    end

    it 'extracts text from documents by default and stores images as images' do
      expect(uploaded_purpose(File.expand_path('../../fixtures/sample.pdf', __dir__))).to eq('file-extract')
      expect(uploaded_purpose(File.expand_path('../../fixtures/ruby.png', __dir__))).to eq('image')
    end

    it 'rejects a retention period' do
      expect { provider.upload_file('x.pdf', expires_in: 60) }.to raise_error(ArgumentError, /expires_in/)
    end

    it 'unwraps extracted text and leaves other files as written' do
      stub_request(:get, 'https://api.moonshot.ai/v1/files/a/content')
        .to_return(status: 200, body: { content: 'text', type: 'file' }.to_json)
      stub_request(:get, 'https://api.moonshot.ai/v1/files/b/content')
        .to_return(status: 200, body: %({"custom_id":"0"}\n{"custom_id":"1"}\n))

      expect(provider.download_file('a')).to eq('text')
      expect(provider.download_file('b')).to include('custom_id')
    end
  end

  describe 'responses' do
    it 'sends user text as input_text parts, because Kimi drops web search for bare strings' do
      request = stub_request(:post, 'https://api.moonshot.ai/v1/responses')
                .with { |sent| JSON.parse(sent.body)['input'].first['content'].first['type'] == 'input_text' }
                .to_return(status: 200, body: { id: 'r', status: 'completed', output: [] }.to_json,
                           headers: { 'Content-Type' => 'application/json' })

      context.chat(model: model_id, provider: :moonshot, protocol: :responses)
             .with_provider_tools(:web_search).ask('Hello')

      expect(request).to have_been_made
    end
  end

  describe 'token counting' do
    it 'estimates through the tokenizer endpoint' do
      request = stub_request(:post, 'https://api.moonshot.ai/v1/tokenizers/estimate-token-count')
                .with { |sent| JSON.parse(sent.body).keys.sort == %w[messages model] }
                .to_return(status: 200, body: { data: { total_tokens: 42 } }.to_json,
                           headers: { 'Content-Type' => 'application/json' })

      expect(context.chat(model: model_id, provider: :moonshot).count_tokens('Hello')).to eq(42)
      expect(request).to have_been_made
    end
  end
end
