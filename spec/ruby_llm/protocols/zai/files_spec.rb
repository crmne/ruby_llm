# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::ZAI::Files do
  let(:provider) do
    config = RubyLLM.config.dup
    config.zai_api_key ||= 'test'
    RubyLLM::Providers::ZAI.new(config)
  end
  let(:protocol) { described_class.new(provider) }
  let(:pdf_path) { File.expand_path('../../../fixtures/sample.pdf', __dir__) }
  let(:pdf) { RubyLLM::Attachment.new(pdf_path) }

  it 'uploads for chat by default and leaves other purposes to Z.ai' do
    expect(protocol.send(:render_upload_payload, pdf)).to include(purpose: 'user_data')
    expect(protocol.send(:render_upload_payload, pdf, purpose: 'agent')).to include(purpose: 'agent')
    expect(provider).to be_files
  end

  it 'rejects the options Z.ai has no field for' do
    expect { provider.upload_file(pdf_path, expires_in: 3600) }.to raise_error(ArgumentError, /expires_in/)
    expect { provider.upload_file(pdf_path, uri: 'somewhere') }.to raise_error(ArgumentError, /uri/)
  end

  it 'reads creation times in milliseconds' do
    file = protocol.send(:parse_file_response, { 'id' => 'a.pdf', 'created_at' => 1_794_255_653_907 })

    expect(file.created_at).to eq(Time.at(1_794_255_653.907))
    expect(file.downloadable).to be(false)
  end

  it 'reports that uploaded files cannot be read back' do
    expect { protocol.find('a.pdf') }.to raise_error(RubyLLM::Error, /does not support retrieving/)
    expect { protocol.download('a.pdf') }.to raise_error(RubyLLM::Error, /does not support downloading/)
  end

  it 'uploads a PDF and answers from it in chat', :live do
    file = RubyLLM.upload(pdf_path, provider: :zai)
    expect(file).to have_attributes(filename: 'sample.pdf', purpose: 'user_data', byte_size: File.size(pdf_path))

    reply = RubyLLM.chat(model: 'glm-5.3-flash', provider: :zai)
                   .ask('What is the title of this document? Answer with the title only.', with: file)

    expect(reply.content).to match(/sample pdf/i)
  ensure
    provider.connection.delete("files/#{file.id}") if file
  end
end
