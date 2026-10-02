# frozen_string_literal: true

module RubyLLM
  class MCP
    class OAuth
      # Signs DPoP proofs (RFC 9449 section 4.2) with the key a token is
      # bound to, carrying the latest nonce each server supplied. Nonces
      # from the authorization server and the resource server stay apart,
      # as section 9 requires.
      class Proofs # :nodoc:
        def initialize
          @nonces = {}
          @keys = {}
        end

        # Returns a proof for a +verb+ request to +url+ with the PEM-encoded
        # key, and with the hash of the access +token+ it accompanies.
        def sign(pem, url, token: nil, verb: 'POST')
          key = @keys[pem] ||= Key.new(pem)
          claims = { jti: SecureRandom.uuid, htm: verb, htu: url.to_s[/\A[^?#]*/], iat: Time.now.to_i,
                     ath: (Base64.urlsafe_encode64(Digest::SHA256.digest(token), padding: false) if token),
                     nonce: @nonces[origin(url)] }
          key.jwt(claims.compact, typ: 'dpop+jwt', jwk: key.jwk)
        end

        def remember(url, nonce)
          @nonces[origin(url)] = nonce if nonce
        end

        private

        def origin(url)
          uri = URI(url.to_s)
          [uri.scheme, uri.host, uri.port]
        end
      end
    end
  end
end
