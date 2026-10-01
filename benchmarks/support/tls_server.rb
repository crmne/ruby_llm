# frozen_string_literal: true

require 'fileutils'
require 'openssl'
require 'socket'

module Benchmarks
  # A loopback HTTPS server that keeps connections alive, answers every
  # request with the same JSON body, and counts the TLS handshakes it
  # completes. Its certificate is self-signed and trusted for this process
  # only, through SSL_CERT_FILE and OpenSSL's default certificate store.
  class TLSServer
    attr_reader :url

    def initialize(body)
      @body = body
      @handshakes = 0
      @lock = Mutex.new
      @context = build_context
      @server = TCPServer.new('127.0.0.1', 0)
      @url = "https://127.0.0.1:#{@server.addr[1]}"
      @acceptor = Thread.new { accept_connections }
    end

    def handshakes
      @lock.synchronize { @handshakes }
    end

    def close
      @acceptor.kill
      @server.close
      FileUtils.rm_f(@certificate_path)
    end

    def self.certificate_for(key)
      certificate = OpenSSL::X509::Certificate.new
      certificate.version = 2
      certificate.serial = 1
      certificate.subject = certificate.issuer = OpenSSL::X509::Name.parse('/CN=127.0.0.1')
      certificate.public_key = key
      certificate.not_before = Time.now - 60
      certificate.not_after = Time.now + 3600
      extensions = OpenSSL::X509::ExtensionFactory.new(certificate, certificate)
      certificate.add_extension(extensions.create_extension('basicConstraints', 'CA:TRUE', true))
      certificate.add_extension(extensions.create_extension('subjectAltName', 'IP:127.0.0.1'))
      certificate.sign(key, OpenSSL::Digest.new('SHA256'))
    end

    private

    def build_context
      key = OpenSSL::PKey::EC.generate('prime256v1')
      certificate = self.class.certificate_for(key)
      trust(certificate)
      OpenSSL::SSL::SSLContext.new.tap do |context|
        context.cert = certificate
        context.key = key
        context.alpn_select_cb = ->(_protocols) { 'http/1.1' }
      end
    end

    # Adapters build their certificate store from SSL_CERT_FILE when they
    # first connect; others use OpenSSL's default store, built at require.
    def trust(certificate)
      @certificate_path = File.join(Benchmarks.scratch('tls'), "certificate-#{Process.pid}.pem")
      File.write(@certificate_path, certificate.to_pem)
      ENV['SSL_CERT_FILE'] = @certificate_path
      OpenSSL::SSL::SSLContext::DEFAULT_CERT_STORE.add_cert(certificate)
    end

    def accept_connections
      loop { Thread.new(@server.accept) { |socket| serve(socket) } }
    rescue IOError, SystemCallError
      nil
    end

    # Without TCP_NODELAY, the server's small writes during the handshake meet
    # the client's delayed ACKs and every new connection waits 40 ms, which no
    # API server makes its clients wait.
    def serve(socket)
      socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
      tls = OpenSSL::SSL::SSLSocket.new(socket, @context)
      tls.sync_close = true
      tls.accept
      @lock.synchronize { @handshakes += 1 }
      while tls.gets
        read_request(tls)
        respond(tls)
      end
    rescue IOError, SystemCallError, OpenSSL::SSL::SSLError
      nil
    ensure
      tls&.close
    end

    # Reads the headers and body that follow a request line.
    def read_request(socket)
      headers = {}
      while (line = socket.gets) && line != "\r\n"
        name, value = line.split(':', 2)
        headers[name.strip.downcase] = value.strip
      end
      headers['transfer-encoding'] == 'chunked' ? read_chunks(socket) : socket.read(headers['content-length'].to_i)
    end

    def read_chunks(socket)
      while (size = socket.gets.to_i(16)).positive?
        socket.read(size + 2)
      end
      socket.gets
    end

    def respond(socket)
      socket.write("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: #{@body.bytesize}\r\n" \
                   "Connection: keep-alive\r\n\r\n#{@body}")
    end
  end
end
