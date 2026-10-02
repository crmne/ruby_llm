# frozen_string_literal: true

require 'socket'

module MCPStreams
  # A request the server received: its HTTP verb, lowercased headers, and
  # JSON body.
  Request = Struct.new(:verb, :headers, :body) do
    def rpc_method
      body&.fetch('method', nil)
    end
  end

  # A loopback Streamable HTTP server for specs. Each connection is answered
  # by the block given to ::new, which receives the Request and a Reply.
  # Streams opened with Reply#stream stay open, so a spec can send events
  # down them, drop them, or end them as a server would.
  class Server
    attr_reader :url

    def initialize(&respond)
      @respond = respond
      @server = TCPServer.new('127.0.0.1', 0)
      @url = "http://127.0.0.1:#{@server.addr[1]}/mcp"
      @lock = Mutex.new
      @requests = []
      @streams = {}
      @threads = []
      @acceptor = Thread.new { accept }
    end

    def requests
      @lock.synchronize { @requests.dup }
    end

    def requests_for(rpc_method)
      requests.select { |request| request.rpc_method == rpc_method }
    end

    def open_streams
      @lock.synchronize { @streams.size }
    end

    def push(message)
      write_event("data: #{JSON.generate(message)}")
    end

    def write_event(event)
      sockets.each { |socket| chunk(socket, "#{event}\n\n") }
    end

    def drop
      sockets.each(&:close)
    end

    def finish
      @lock.synchronize { @streams.dup }.each do |socket, request|
        id = request.body['id']
        chunk(socket, "data: #{JSON.generate(jsonrpc: '2.0', id:, result: { resultType: 'complete' })}\n\n")
        write(socket, "0\r\n\r\n")
        socket.close
      end
    end

    def close
      @acceptor.kill
      @server.close
      @threads.each(&:kill)
      sockets.each(&:close)
    end

    def stream(socket, request, messages)
      socket.write("HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nTransfer-Encoding: chunked\r\n\r\n")
      @lock.synchronize do
        @streams[socket] = request
        messages.each { |message| chunk(socket, "data: #{JSON.generate(message)}\n\n") }
      end
      socket.read
    ensure
      @lock.synchronize { @streams.delete(socket) }
    end

    private

    def sockets
      @lock.synchronize { @streams.keys }
    end

    def chunk(socket, data)
      write(socket, "#{data.bytesize.to_s(16)}\r\n#{data}\r\n")
    end

    # A client may close a stream as soon as it reads the answer, and the
    # thread serving it then closes its end, so writes that follow find it
    # gone.
    def write(socket, data)
      socket.write(data)
    rescue IOError, SystemCallError
      nil
    end

    def accept
      loop do
        socket = @server.accept
        @threads << Thread.new(socket) { |client| serve(client) }
      end
    rescue IOError, SystemCallError
      nil
    end

    def serve(socket)
      verb = socket.gets&.split&.first or return
      headers = read_headers(socket)
      length = headers['content-length'].to_i
      request = Request.new(verb, headers, (JSON.parse(socket.read(length)) if length.positive?))
      @lock.synchronize { @requests << request }
      @respond.call(request, Reply.new(self, socket, request))
    rescue IOError, SystemCallError
      nil
    ensure
      socket.close unless socket.closed?
    end

    def read_headers(socket)
      headers = {}
      while (line = socket.gets) && line != "\r\n"
        name, value = line.split(':', 2)
        headers[name.strip.downcase] = value.strip
      end
      headers
    end
  end

  # How the server answers one request.
  class Reply
    def initialize(server, socket, request)
      @server = server
      @socket = socket
      @request = request
    end

    def json(status: 200, headers: {}, **fields)
      body = JSON.generate({ jsonrpc: '2.0', id: @request.body&.fetch('id', nil) }.merge(fields))
      respond(status, body, headers.merge('Content-Type' => 'application/json'))
    end

    def status(code, headers: {})
      respond(code, '', headers)
    end

    def stream(*messages)
      @server.stream(@socket, @request, messages)
    end

    private

    def respond(status, body, headers)
      head = headers.merge('Content-Length' => body.bytesize, 'Connection' => 'close')
                    .map { |name, value| "#{name}: #{value}\r\n" }.join
      @socket.write("HTTP/1.1 #{status} Status\r\n#{head}\r\n#{body}")
    end
  end
end
