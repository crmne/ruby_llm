# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe RubyLLM::Downloads do
  let(:connection) { instance_double(RubyLLM::Connection) }
  let(:host_class) do
    Class.new do
      include RubyLLM::Downloads

      attr_reader :connection

      def initialize(connection)
        @connection = connection
      end

      def download_file_url(file_id)
        "files/#{file_id}/content"
      end

      def try_parse_json(maybe_json)
        JSON.parse(maybe_json)
      rescue JSON::ParserError
        maybe_json
      end

      def parse_error(response)
        response.body.dig('error', 'message')
      end
    end
  end
  let(:host) { host_class.new(connection) }

  describe '#download_file' do
    context 'when download targets are invalid' do
      it 'raises when io and path are both provided' do
        expect do
          host.download_file('file_123', io: StringIO.new, path: 'tmp/file.bin')
        end.to raise_error(ArgumentError, 'Specify only one of io:, path:, or tempfile: true')
      end

      it 'raises when io and tempfile are both provided' do
        expect do
          host.download_file('file_123', io: StringIO.new, tempfile: true)
        end.to raise_error(ArgumentError, 'Specify only one of io:, path:, or tempfile: true')
      end

      it 'raises when path and tempfile are both provided' do
        expect do
          host.download_file('file_123', path: 'tmp/file.bin', tempfile: true)
        end.to raise_error(ArgumentError, 'Specify only one of io:, path:, or tempfile: true')
      end

      it 'raises when a block is provided with path' do
        expect do
          host.download_file('file_123', path: 'tmp/file.bin') { |_path| :unused }
        end.to raise_error(ArgumentError, 'Block form is only supported with io: or tempfile: true')
      end
    end

    context 'when no destination is provided' do
      it 'returns the response body' do
        response = instance_double(Faraday::Response, body: 'downloaded binary data')

        allow(connection).to receive(:raw_get).with('files/file_123/content') do |&block|
          req = Struct.new(:headers).new({})
          block.call(req)
          expect(req.headers['Accept']).to eq('application/octet-stream')
          response
        end

        expect(host.download_file('file_123')).to eq('downloaded binary data')
        expect(connection).to have_received(:raw_get).with('files/file_123/content')
      end
    end

    context 'with io' do
      it 'streams content into the provided io and rewinds it' do
        io = StringIO.new

        allow(host).to receive(:stream_download_to) do |_url, destination|
          destination.write('hello world')
        end

        result = host.download_file('file_123', io: io)

        expect(result).to be(io)
        expect(result.read).to eq('hello world')
        expect(result.pos).to eq(11)
        expect(io.string).to eq('hello world')
      end

      it 'yields the provided io to the block' do
        io = StringIO.new

        allow(host).to receive(:stream_download_to) do |_url, destination|
          destination.write('hello world')
        end

        yielded = nil
        result = host.download_file('file_123', io: io) do |downloaded_io|
          yielded = downloaded_io.read
          :block_result
        end

        expect(yielded).to eq('hello world')
        expect(result).to eq(:block_result)
      end
    end

    context 'with path' do
      it 'writes content to disk and returns the path' do
        Dir.mktmpdir do |dir|
          path = File.join(dir, 'download.bin')

          allow(host).to receive(:stream_download_to) do |_url, destination|
            destination.write("\x00\x01download")
          end

          result = host.download_file('file_123', path: path)

          expect(result).to eq(path)
          expect(File.binread(path)).to eq("\x00\x01download")
        end
      end
    end

    context 'with tempfile' do
      it 'returns a rewound tempfile containing the download' do
        allow(host).to receive(:stream_download_to) do |_url, destination|
          destination.write('tempfile content')
        end

        tempfile = host.download_file('file_123', tempfile: true)

        expect(tempfile).to be_a(Tempfile)
        expect(tempfile.read).to eq('tempfile content')
        expect(tempfile.path).to be_present
      ensure
        tempfile.close! if tempfile && !tempfile.closed?
      end

      it 'yields the tempfile and cleans it up after the block' do
        allow(host).to receive(:stream_download_to) do |_url, destination|
          destination.write('tempfile content')
        end

        yielded_path = nil
        yielded_content = nil

        result = host.download_file('file_123', tempfile: true) do |file|
          yielded_path = file.path
          yielded_content = file.read
          expect(File.exist?(yielded_path)).to be true
          :done
        end

        expect(result).to eq(:done)
        expect(yielded_content).to eq('tempfile content')
        expect(File.exist?(yielded_path)).to be false
      end

      it 'cleans up the tempfile when the block raises' do
        allow(host).to receive(:stream_download_to) do |_url, destination|
          destination.write('tempfile content')
        end

        yielded_path = nil

        expect do
          host.download_file('file_123', tempfile: true) do |file|
            yielded_path = file.path
            raise 'boom'
          end
        end.to raise_error(RuntimeError, 'boom')

        expect(File.exist?(yielded_path)).to be false
      end
    end
  end

  describe '#stream_download_to' do
    let(:url) { 'files/file_123/content' }

    context 'with Faraday version 1' do
      before do
        stub_const('Faraday::VERSION', '1.10.0')
      end

      it 'writes chunks using req.options[:on_data]' do
        destination = StringIO.new
        request = Struct.new(:headers, :options).new({}, {})

        allow(connection).to receive(:raw_get).with(url) do |&block|
          block.call(request)
          request.options[:on_data].call('chunk one', 9)
          request.options[:on_data].call(' chunk two', 19)
        end

        host.send(:stream_download_to, url, destination)

        expect(connection).to have_received(:raw_get).with(url)
        expect(request.headers['Accept']).to eq('application/octet-stream')
        expect(destination.string).to eq('chunk one chunk two')
      end
    end

    context 'with Faraday version 2' do
      before do
        stub_const('Faraday::VERSION', '2.0.0')
      end

      it 'writes successful chunks using req.options.on_data' do
        destination = StringIO.new
        options = Struct.new(:on_data).new
        request = Struct.new(:headers, :options).new({}, options)
        env = Struct.new(:status).new(200)

        allow(connection).to receive(:raw_get).with(url) do |&block|
          block.call(request)
          request.options.on_data.call('chunk one', 9, env)
          request.options.on_data.call(' chunk two', 19, env)
        end

        host.send(:stream_download_to, url, destination)

        expect(connection).to have_received(:raw_get).with(url)
        expect(request.headers['Accept']).to eq('application/octet-stream')
        expect(destination.string).to eq('chunk one chunk two')
      end

      it 'raises parsed download errors for unsuccessful chunks' do
        destination = StringIO.new
        options = Struct.new(:on_data).new
        request = Struct.new(:headers, :options).new({}, options)
        env = Struct.new(:status, :merge).new(500, nil)
        allow(env).to receive(:merge).with(body: { 'error' => { 'message' => 'boom' } })
                                     .and_return(Struct.new(:status, :body).new(500,
                                                                                { 'error' => { 'message' => 'boom' } }))

        allow(connection).to receive(:raw_get).with(url) do |&block|
          block.call(request)
          request.options.on_data.call('{"error":{"message":"boom"}}', 28, env)
        end

        expect do
          host.send(:stream_download_to, url, destination)
        end.to raise_error(RubyLLM::ServerError, 'boom')
        expect(connection).to have_received(:raw_get).with(url)
      end
    end
  end
end
