# frozen_string_literal: true

require 'socket'
require_relative '../../.github/triage/assess'

RSpec.describe 'Issue assessment Copilot integration', type: :task do
  it 'makes one request with no tools through the installed CLI, using an offline fake provider' do
    skip 'Install Copilot CLI to run this offline integration check' unless copilot_installed?

    requests = []
    server = TCPServer.new('127.0.0.1', 0)
    worker = serve_model(server, requests)
    previous = ENV.to_h
    ENV.update('COPILOT_OFFLINE' => 'true', 'COPILOT_PROVIDER_TYPE' => 'openai',
               'COPILOT_PROVIDER_BASE_URL' => "http://127.0.0.1:#{server.addr[1]}/v1",
               'COPILOT_PROVIDER_WIRE_API' => 'completions', 'COPILOT_PROVIDER_WIRE_MODEL' => 'gpt-5.6-luna')
    assessment = IssueAssessment.new('GITHUB_REPOSITORY' => 'crmne/ruby_llm', 'TRIAGE_NUMBER' => '123',
                                     'COPILOT_GITHUB_TOKEN' => 'offline-test')
    allow(assessment).to receive(:puts)

    response = assessment.send(:ask_copilot, 'Return JSON only: {"labels":[],"reply":null}')

    expect(JSON.parse(response)).to eq('labels' => [], 'reply' => nil)
    expect(requests.size).to eq(1)
    expect(requests.first.fetch('tools', [])).to be_empty
  ensure
    ENV.replace(previous) if previous
    worker&.kill&.join
    server&.close
  end

  def copilot_installed?
    ENV.fetch('PATH').split(File::PATH_SEPARATOR).any? { |directory| File.executable?(File.join(directory, 'copilot')) }
  end

  def serve_model(server, requests)
    Thread.new do
      loop do
        socket = server.accept
        socket.gets
        headers = {}
        while (line = socket.gets) != "\r\n"
          name, value = line.split(':', 2)
          headers[name.downcase] = value.strip
        end
        requests << JSON.parse(socket.read(Integer(headers.fetch('content-length'))))
        body = completion
        socket.write("HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\n")
        socket.write("Content-Length: #{body.bytesize}\r\n\r\n#{body}")
        socket.close
      end
    end
  end

  def completion
    chunk = {
      id: 'offline-completion', object: 'chat.completion.chunk', created: 1, model: 'gpt-5.6-luna',
      choices: [{ index: 0, finish_reason: 'stop',
                  delta: { role: 'assistant', content: '{"labels":[],"reply":null}' } }]
    }
    "data: #{JSON.generate(chunk)}\n\ndata: [DONE]\n\n"
  end
end
