# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Gemini::FileUploadService do
  include_context 'with configured RubyLLM'

  let(:connection) { instance_double(Faraday::Connection) }
  let(:config) { RubyLLM.config }
  let(:service) { described_class.new(config) }

  let(:attachment) do
    instance_double(
      RubyLLM::Attachment,
      size: 25_000_000,
      mime_type: 'video/mp4',
      filename: 'test_video.mp4',
      source: '/path/to/video.mp4'
    )
  end

  describe '#upload' do
    it 'returns the file URI' do
      allow(File).to receive(:binread).and_return('file_content')

      # Create a test service to get access to @faraday
      faraday = service.instance_variable_get(:@faraday)

      # Mock first POST (initiate)
      initiate_request = instance_double(Faraday::Request)
      allow(initiate_request).to receive(:headers).and_return({})
      allow(initiate_request).to receive(:headers=)
      allow(initiate_request).to receive(:body=).with({
        file: { display_name: 'test_video.mp4' }
      }.to_json)

      initiate_response = instance_double(Faraday::Response, headers: { 'x-guploader-uploadid' => 'upload_123' })

      # Mock second POST (upload content)
      upload_request = instance_double(Faraday::Request)
      allow(upload_request).to receive(:params=)
      allow(upload_request).to receive_messages(params: {}, headers: {})
      allow(upload_request).to receive(:headers=)
      allow(upload_request).to receive(:body=)

      upload_response = instance_double(Faraday::Response, body: {
                                          'file' => {
                                            'uri' => 'https://generativelanguage.googleapis.com/v1beta/files/abc123'
                                          }
                                        })

      # Mock GET for status check (assume immediate success)
      status_response = instance_double(Faraday::Response, body: { 'state' => 'ACTIVE' })

      # Set up POST mock with block to differentiate calls
      call_count = 0
      allow(faraday).to receive(:post) do |&block|
        call_count += 1
        if call_count == 1
          # First call - initiate
          block&.call(initiate_request)
          initiate_response
        else
          # Second call - upload content
          block&.call(upload_request)
          upload_response
        end
      end

      allow(faraday).to receive(:get).with('v1beta/files/abc123').and_return(status_response)

      # Execute
      result = service.upload(attachment)

      # Verify
      expect(result).to eq('https://generativelanguage.googleapis.com/v1beta/files/abc123')
    end
  end
end
