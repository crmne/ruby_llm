# frozen_string_literal: true

require 'rails_helper'
require 'rack/test'
require 'open3'
require 'tmpdir'

RSpec.describe 'Rails persistence guide', type: :request do
  include_context 'with configured RubyLLM'

  let(:chat) { RubyLLM.chat(model: model_for(:openai)) }
  let(:guide_text) { File.read(File.expand_path('../../docs/_advanced/rails-persistence.md', __dir__)) }
  let(:prompt) { 'What is in this file?' }
  let(:session) { Rack::Test::Session.new(Rack::MockSession.new(controller_class.action(:create))) }
  let(:controller_class) do
    path = File.expand_path('../../docs/_advanced/rails-persistence.md', __dir__)
    example = guide_text.scan(/```ruby\n(.*?)```/m).flatten.find { |code| code.include?('params[:uploaded_file]') }
    raise 'Missing upload example in Rails persistence guide' unless example

    stub_const('UploadExampleController', Class.new(ActionController::Base) do
      attr_accessor :chat
      alias_method :chat_record, :chat
    end).tap do |controller|
      action = "def create\n#{example}\nhead :no_content\nend"
      controller.class_eval(action, path, 1)
    end
  end

  before do
    controller = controller_class.new
    controller.chat = chat
    allow(controller_class).to receive(:new).and_return(controller)
    allow(chat).to receive(:complete).and_return(RubyLLM::Message.new(role: :assistant, content: 'Received'))
    allow(chat).to receive(:ask).and_call_original
  end

  shared_examples 'upload validation' do
    [
      'http://127.0.0.1:9292/collect',
      'http://169.254.169.254/latest/meta-data/',
      'http://[::1]/collect',
      'https://example.com/report.pdf'
    ].each do |url|
      it "rejects a URL string upload: #{url}" do
        request = stub_request(:get, url).to_return(body: 'internal-secret-data')

        session.post('/chat', uploaded_file: url)

        expect(session.last_response.status).to eq(400)
        expect(chat).not_to have_received(:ask)
        expect(request).not_to have_been_requested
      end
    end

    ['spec/fixtures/ruby.txt', File.expand_path('../fixtures/ruby.txt', __dir__)].each do |path|
      it "rejects a local path string upload: #{path}" do
        allow(File).to receive(:binread).and_call_original

        session.post('/chat', uploaded_file: path)

        expect(session.last_response.status).to eq(400)
        expect(chat).not_to have_received(:ask)
        expect(File).not_to have_received(:binread).with(Pathname.new(path))
      end
    end

    [nil, '', ['spec/fixtures/ruby.txt'], { file: 'spec/fixtures/ruby.txt' }].each do |value|
      it "rejects a missing or malformed upload: #{value.inspect}" do
        session.post('/chat', uploaded_file: value)

        expect(session.last_response.status).to eq(400)
        expect(chat).not_to have_received(:ask)
      end
    end

    it 'accepts a multipart file upload' do
      path = File.expand_path('../fixtures/ruby.txt', __dir__)
      upload = Rack::Test::UploadedFile.new(path, 'text/plain')

      session.post('/chat', uploaded_file: upload)

      expect(session.last_response.status).to eq(204)
      expect(chat).to have_received(:ask).with(prompt, with: an_instance_of(ActionDispatch::Http::UploadedFile))
      attachment = chat.messages.first.attachments.first
      expect(attachment.filename).to eq('ruby.txt')
      expect(attachment.content).to eq(File.read(path))
    end
  end

  it_behaves_like 'upload validation'

  context 'with the frozen 1.x guide' do
    let(:prompt) { 'Analyze this file' }
    let(:guide_text) do
      Dir.mktmpdir('rubyllm-frozen-docs') do |directory|
        %w[_advanced _includes _layouts _sass/custom].each { |name| FileUtils.mkdir_p(File.join(directory, name)) }
        File.write(File.join(directory, '_config.yml'), '{}')
        File.write(File.join(directory, '_sass/custom/custom.scss'), '')
        File.write(File.join(directory, '_includes/head.html'), '')
        File.write(File.join(directory, '_includes/head_custom.html'), '')
        File.write(File.join(directory, '_layouts/default.html'), '')
        path = File.join(directory, '_advanced/rails.md')
        FileUtils.cp(File.expand_path('../fixtures/docs/one_x_rails.md', __dir__), path)
        script = File.expand_path('../../docs/bin/prepare_one_x_docs.rb', __dir__)
        output, status = Open3.capture2e(RbConfig.ruby, script, directory)
        raise output unless status.success?

        File.read(path)
      end
    end

    it_behaves_like 'upload validation'
  end
end
