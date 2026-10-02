# frozen_string_literal: true

module RubyLLM
  class MCP
    class OAuth
      # A private key that signs JSON Web Tokens with JWS (RFC 7515): the
      # client assertions of private_key_jwt (RFC 7523 section 2.2) and
      # DPoP proofs (RFC 9449 section 4.2). Takes an RSA or elliptic curve
      # key, as a PEM string or an OpenSSL key.
      class Key # :nodoc:
        CURVES = { 'prime256v1' => %w[P-256 ES256], 'secp384r1' => %w[P-384 ES384],
                   'secp521r1' => %w[P-521 ES512] }.freeze
        RSA_ALGORITHMS = %w[RS256 PS256 RS384 PS384 RS512 PS512].freeze

        def self.generate
          new(OpenSSL::PKey::EC.generate('prime256v1'))
        end

        def initialize(key)
          @key = key.is_a?(OpenSSL::PKey::PKey) ? key : OpenSSL::PKey.read(key.to_s)
          return if @key.is_a?(OpenSSL::PKey::RSA) || (@key.is_a?(OpenSSL::PKey::EC) && CURVES[curve_name])

          raise ArgumentError, 'OAuth private keys must be RSA or EC keys on P-256, P-384, or P-521'
        end

        # Returns the JWS algorithm this key signs with, preferring one of
        # +supported+ when the authorization server lists them.
        def algorithm(supported = nil)
          candidates = @key.is_a?(OpenSSL::PKey::RSA) ? RSA_ALGORITHMS : [CURVES[curve_name].last]
          (candidates & Array(supported)).first || candidates.first
        end

        def jwt(claims, algorithm: self.algorithm, **header)
          input = [header.merge(alg: algorithm), claims].map { |part| encode(JSON.generate(part)) }.join('.')
          "#{input}.#{encode(sign(input, algorithm))}"
        end

        # Returns the public half of an elliptic curve key as a JSON Web Key
        # (RFC 7518 section 6.2.1).
        def jwk
          point = @key.public_key.to_octet_string(:uncompressed)
          size = point.bytesize / 2
          { kty: 'EC', crv: CURVES[curve_name].first, x: encode(point[1, size]), y: encode(point[size + 1, size]) }
        end

        def to_pem
          @key.private_to_pem
        end

        private

        def sign(input, algorithm)
          digest = "SHA#{algorithm[2..]}"
          case algorithm[0, 2]
          when 'PS' then @key.sign_pss(digest, input, salt_length: :digest, mgf1_hash: digest)
          when 'ES' then concatenated(@key.sign(digest, input))
          else @key.sign(digest, input)
          end
        end

        # JWS carries ECDSA signatures as R and S side by side (RFC 7518
        # section 3.4), where OpenSSL returns them DER encoded.
        def concatenated(der)
          size = (@key.group.degree + 7) / 8
          OpenSSL::ASN1.decode(der).value.map { |integer| integer.value.to_s(2).rjust(size, "\0") }.join
        end

        def curve_name
          @key.group.curve_name
        end

        def encode(data)
          Base64.urlsafe_encode64(data, padding: false)
        end
      end
    end
  end
end
