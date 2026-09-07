# frozen_string_literal: true

require 'socket'
require 'openssl'
require 'io/wait'

module RubyLLM
  module Transport # :nodoc:
    class WebsocketConnection # :nodoc: all
      MAX_FRAME_BYTES = 16 * 1024 * 1024

      attr_reader :url

      def self.open(url, headers:, config:)
        connection = new(url, headers:, config:)
        connection.connect
        yield connection
      ensure
        connection&.close
      end

      def initialize(url, headers:, config:)
        @url = url
        @uri = URI.parse(url)
        raise ArgumentError, 'WebSocket URL must use ws or wss' unless %w[ws wss].include?(@uri.scheme)
        if @uri.userinfo || @uri.fragment
          raise ArgumentError, 'WebSocket URL must not contain credentials or a fragment'
        end
        raise ArgumentError, 'WebSocket connections do not support HTTP proxies' if config.http_proxy

        @headers = headers
        @timeout = config.request_timeout
        @messages = []
        @write_lock = Mutex.new
      end

      def connect
        load_driver
        deadline = monotonic_time + @timeout
        open_socket(deadline)
        configure_driver
        @driver.start
        read_frame(deadline) until @opened || @closed || @error
        raise @error if @error
        raise Error, 'WebSocket closed before opening' unless @opened

        self
      rescue StandardError
        close
        raise
      end

      def send_text(text)
        ensure_open
        @driver.text(text)
      end

      def send_binary(data)
        ensure_open
        @driver.binary(data.b)
      end

      def read(timeout: @timeout)
        deadline = monotonic_time + timeout
        read_frame(deadline) while @messages.empty? && !@closed && !@error
        raise @error if @error

        @messages.shift
      rescue IOError, SystemCallError, OpenSSL::SSL::SSLError
        raise unless @closed
      end

      def read_available
        ensure_open
        until @messages.any? || @closed || @error
          break unless read_available_frame
        end
        ensure_open

        @messages.shift
      rescue EOFError, Errno::ECONNRESET
        @closed = true
        raise Error, 'WebSocket connection ended without a close frame'
      rescue IOError, SystemCallError, OpenSSL::SSL::SSLError
        raise unless @closed
      end

      def each_message(write:)
        writer_error = nil
        writer = Thread.new do
          write.call(self)
        rescue StandardError => e
          writer_error = e
          close
        end
        writer.report_on_exception = false

        while (message = read)
          yield message
        end
        finish_writer(writer)
        raise writer_error if writer_error
      rescue StandardError => e
        raise writer_error || e
      ensure
        close
        writer.kill.join if writer&.alive?
      end

      def close
        @driver.close if @driver && @opened && !@closed
      rescue IOError, SystemCallError, OpenSSL::SSL::SSLError, Error
        nil
      ensure
        @closed = true
        close_socket
      end

      def write(data)
        @write_lock.synchronize do
          deadline = monotonic_time + @timeout
          offset = 0
          while offset < data.bytesize
            written = socket_operation(deadline) { @socket.write_nonblock(data.byteslice(offset..)) }
            offset += written
          end
        end
        data.bytesize
      end

      private

      def read_available_frame
        data = @socket.read_nonblock(16_384, exception: false)
        return if %i[wait_readable wait_writable].include?(data)

        raise EOFError unless data

        @driver.parse(data)
        data
      end

      def finish_writer(writer)
        raise Error, 'WebSocket closed before outgoing messages finished' unless writer.join(1)
      end

      def configure_driver
        @driver = WebSocket::Driver.client(self, max_length: MAX_FRAME_BYTES)
        @headers.each { |name, value| @driver.set_header(name, value) if value }
        @driver.on(:open) { @opened = true }
        @driver.on(:message) { |event| @messages << event.data }
        @driver.on(:error) { |event| @error = Error.new(event.message) }
        @driver.on(:close) do |event|
          @closed = true
          @error ||= Error.new("WebSocket closed with code #{event.code}: #{event.reason}") unless event.code == 1000
        end
      end

      def open_socket(deadline)
        port = @uri.port || (@uri.scheme == 'wss' ? 443 : 80)
        @socket = Socket.tcp(@uri.host, port, connect_timeout: @timeout)
        secure_socket(deadline) if @uri.scheme == 'wss'
      end

      def close_socket
        @socket.close if @socket && !@socket.closed?
      end

      def load_driver
        require 'websocket/driver'
      rescue LoadError
        raise LoadError, 'WebSocket streaming requires websocket-driver. Add gem "websocket-driver" to your Gemfile.'
      end

      def secure_socket(deadline)
        context = OpenSSL::SSL::SSLContext.new
        context.set_params
        socket = OpenSSL::SSL::SSLSocket.new(@socket, context)
        socket.hostname = @uri.host
        socket.sync_close = true
        @socket = socket
        socket_operation(deadline) { @socket.connect_nonblock }
        @socket.post_connection_check(@uri.host)
      end

      def ensure_open
        raise Error, 'WebSocket connection is closed' unless @opened && !@closed
        raise @error if @error
      end

      def read_frame(deadline)
        data = socket_operation(deadline) { @socket.read_nonblock(16_384) }
        @driver.parse(data)
      rescue EOFError, Errno::ECONNRESET
        @closed = true
        @error ||= Error.new('WebSocket connection ended without a close frame')
      end

      def socket_operation(deadline)
        yield
      rescue IO::WaitReadable
        wait_for_socket(:wait_readable, deadline)
        retry
      rescue IO::WaitWritable
        wait_for_socket(:wait_writable, deadline)
        retry
      end

      def wait_for_socket(method, deadline)
        remaining = deadline - monotonic_time
        raise Error, 'WebSocket operation timed out' unless remaining.positive?
        raise Error, 'WebSocket operation timed out' unless @socket.public_send(method, remaining)
      end

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
