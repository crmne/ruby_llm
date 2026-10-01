# frozen_string_literal: true

require 'socket'

module KeepAlive
  # A loopback HTTP/1.1 server that keeps connections open and records which
  # one served each request, so specs can tell a reused socket from a new one.
  class Server
    attr_reader :url

    def initialize
      @server = TCPServer.new('127.0.0.1', 0)
      @url = "http://127.0.0.1:#{@server.addr[1]}"
      @lock = Mutex.new
      @connections = 0
      @requests = []
      @authorizations = []
      @clients = []
      @acceptor = Thread.new { accept_connections }
    end

    def authorizations
      @lock.synchronize { @authorizations.dup }
    end

    # The number of the connection, counted in order of acceptance, that
    # served each request.
    def requests
      @lock.synchronize { @requests.dup }
    end

    def close
      @acceptor.kill
      @server.close
      @clients.each(&:kill)
    end

    private

    def accept_connections
      loop do
        socket = @server.accept
        number = @lock.synchronize { @connections += 1 }
        @clients << Thread.new(socket) { |client| serve(client, number) }
      end
    rescue IOError, SystemCallError
      nil
    end

    def serve(socket, number)
      while (request_line = socket.gets)
        headers = read_headers(socket)
        body = JSON.parse(socket.read(headers['content-length'].to_i))
        @lock.synchronize do
          @requests << number
          @authorizations << headers['authorization']
        end
        write_json(socket, response_for(request_line.split[1], body))
      end
    rescue IOError, SystemCallError
      nil
    ensure
      socket.close
    end

    def read_headers(socket)
      headers = {}
      while (line = socket.gets) && line != "\r\n"
        name, value = line.split(':', 2)
        headers[name.strip.downcase] = value.strip
      end
      headers
    end

    def response_for(path, body)
      if path.end_with?('/systemone')
        answers = body['questions'].keys.to_h { |id| [id, { 'type' => 'noul', 'noul' => 0.79 }] }
        { 'model' => body['model'], 'answers' => answers, 'usage' => { 'input_tokens' => 9, 'output_tokens' => 1 } }
      else
        { 'data' => [{ 'index' => 0, 'embedding' => [0.1, 0.2] }], 'model' => body['model'],
          'usage' => { 'prompt_tokens' => 2, 'total_tokens' => 2 } }
      end
    end

    def write_json(socket, data)
      body = JSON.generate(data)
      socket.write("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n" \
                   "Content-Length: #{body.bytesize}\r\n\r\n#{body}")
    end
  end

  # A Faraday adapter that keeps one socket open across requests, as the
  # keep-alive adapters applications configure do.
  class Adapter < Faraday::Adapter
    def initialize(...)
      super
      @lock = Mutex.new
    end

    def call(env)
      super
      status, headers, body = @lock.synchronize { exchange(env) }
      save_response(env, status, body, headers)
      @app.call(env)
    end

    private

    def exchange(env)
      @socket ||= Socket.tcp(env.url.host, env.url.port)
      @socket.write(request(env))
      response(@socket)
    end

    def request(env)
      body = env.body.to_s
      headers = env.request_headers.to_h
      headers['Host'] = "#{env.url.host}:#{env.url.port}"
      headers['Content-Length'] = body.bytesize.to_s
      head = ["#{env.method.to_s.upcase} #{env.url.request_uri} HTTP/1.1"]
      head.concat(headers.map { |name, value| "#{name}: #{value}" })
      "#{head.join("\r\n")}\r\n\r\n#{body}"
    end

    def response(socket)
      status = socket.gets.split[1].to_i
      headers = {}
      while (line = socket.gets) != "\r\n"
        name, value = line.split(':', 2)
        headers[name.strip] = value.strip
      end
      [status, headers, socket.read(headers['Content-Length'].to_i)]
    end
  end
end
