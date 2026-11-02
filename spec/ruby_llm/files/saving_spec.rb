# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe RubyLLM::Files::Saving do
  {
    'DownloadedFile' => -> { RubyLLM::DownloadedFile.new("\xFFbytes".b) },
    'Image' => -> { RubyLLM::Image.new(data: Base64.strict_encode64("\xFFbytes".b), mime_type: 'image/png') },
    'Speech' => -> { RubyLLM::Speech.new(data: "\xFFbytes".b, model: 'tts') },
    'Video' => -> { RubyLLM::Video.new(data: "\xFFbytes".b) },
    'MCP::Resource' => lambda {
      RubyLLM::MCP::Resource.new(nil, { 'uri' => 'file:///a', 'blob' => Base64.strict_encode64("\xFFbytes".b) })
    }
  }.each do |name, build|
    it "writes the bytes of a #{name} and returns the path as given" do
      Dir.mktmpdir do |directory|
        path = File.join(directory, 'result.bin')

        expect(build.call.save(path)).to equal(path)
        expect(File.binread(path)).to eq("\xFFbytes".b)
      end
    end
  end

  it 'expands the path before writing' do
    allow(File).to receive(:binwrite)

    expect(RubyLLM::DownloadedFile.new('bytes').save('~/result.bin')).to eq('~/result.bin')
    expect(File).to have_received(:binwrite).with(File.expand_path('~/result.bin'), 'bytes')
  end
end
