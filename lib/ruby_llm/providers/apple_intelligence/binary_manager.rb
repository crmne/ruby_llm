# frozen_string_literal: true

require 'open-uri'
require 'fileutils'

module RubyLLM
  module Providers
    class AppleIntelligence
      # Manages downloading, caching, and locating the osx-ai-inloop binary
      module BinaryManager
        BINARY_URL = 'https://github.com/inloopstudio-team/apple-intelligence-inloop/raw/refs/heads/main/bin/osx-ai-inloop-arm64'
        DEFAULT_CACHE_DIR = File.join(Dir.home, '.ruby_llm', 'bin')
        DEFAULT_BINARY_NAME = 'osx-ai-inloop'

        module_function

        def binary_path(config = nil)
          custom = config&.apple_intelligence_binary_path
          return custom if custom && File.executable?(custom)

          default_path = File.join(DEFAULT_CACHE_DIR, DEFAULT_BINARY_NAME)
          ensure_binary!(default_path) unless File.executable?(default_path)
          default_path
        end

        def ensure_binary!(path)
          check_platform!
          download_binary!(path)
          File.chmod(0o755, path)
        end

        def check_platform!
          unless RUBY_PLATFORM =~ /darwin/
            raise RubyLLM::Error, 'Apple Intelligence provider requires macOS'
          end

          unless RUBY_PLATFORM =~ /arm64/
            RubyLLM.logger.warn('Apple Intelligence binary is built for arm64. ' \
                                'It may not work on this architecture.')
          end
        end

        def download_binary!(path)
          FileUtils.mkdir_p(File.dirname(path))
          RubyLLM.logger.info("Downloading osx-ai-inloop binary to #{path}...")

          URI.open(BINARY_URL, 'rb') do |remote| # rubocop:disable Security/Open
            File.open(path, 'wb') do |local|
              local.write(remote.read)
            end
          end

          RubyLLM.logger.info('Binary downloaded successfully.')
        rescue OpenURI::HTTPError, SocketError, Errno::ECONNREFUSED => e
          raise RubyLLM::Error, "Failed to download Apple Intelligence binary: #{e.message}"
        end
      end
    end
  end
end
