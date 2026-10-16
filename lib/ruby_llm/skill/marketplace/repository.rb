# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'rubygems/package'
require 'stringio'
require 'tmpdir'
require 'zlib'

module RubyLLM
  class Skill
    class Marketplace
      # Where a marketplace's files come from: a local directory, read in
      # place, or a GitHub repository, downloaded as one archive and
      # extracted into a temporary directory.
      class Repository # :nodoc:
        NAME = %r{\A[\w.-]+/[\w.-]+\z}
        REF = %r{\A[\w./-]+\z}
        MAX_BYTES = 128 * 1024 * 1024
        COMMIT = /\A\d+ comment=(\h{40})\n/

        def initialize(source)
          @source = source.to_s
          return if directory?

          @name, @ref = @source.split('@', 2)
          return if @name.to_s.match?(NAME) && (@ref.nil? || @ref.match?(REF))

          raise ArgumentError, "#{@source.inspect} is neither a directory nor a GitHub repository like owner/repo"
        end

        def checkout
          return yield(Pathname.new(File.realpath(@source)), nil) if directory?

          Dir.mktmpdir('ruby_llm-marketplace') do |directory|
            tar = unzip(download)
            extract(tar, directory)
            yield Pathname.new(File.realpath(directory)), tar.byteslice(512, 512).to_s[COMMIT, 1]
          end
        end

        private

        def directory?
          File.directory?(@source)
        end

        def download
          Transport::Connection.basic.get("https://codeload.github.com/#{@name}/tar.gz/#{@ref || 'HEAD'}").body
        rescue Faraday::ResourceNotFound
          raise MarketplaceNotFoundError, "No GitHub repository #{@source}"
        end

        def unzip(archive)
          tar = Zlib::GzipReader.new(StringIO.new(archive)).read(MAX_BYTES + 1).to_s
          return tar if tar.bytesize <= MAX_BYTES

          raise InvalidMarketplaceError, "#{@source} is larger than #{MAX_BYTES} bytes"
        rescue Zlib::Error
          raise InvalidMarketplaceError, "#{@source} did not return a gzip archive"
        end

        def extract(tar, directory)
          Gem::Package::TarReader.new(StringIO.new(tar)) do |reader|
            reader.each do |entry|
              next unless entry.file?

              parts = entry.full_name.split('/').drop(1)
              next if parts.empty?

              write(File.join(directory, *safe(parts, entry.full_name)), entry)
            end
          end
        rescue Gem::Package::TarInvalidError
          raise InvalidMarketplaceError, "#{@source} did not return a tar archive"
        end

        def safe(parts, name)
          return parts unless parts.intersect?(['..', '']) || name.include?("\0") || name.include?('\\')

          raise InvalidMarketplaceError, "#{@source} holds an unsafe path, #{name.inspect}"
        end

        def write(path, entry)
          FileUtils.mkdir_p(File.dirname(path))
          File.binwrite(path, entry.read.to_s)
          File.chmod(0o755, path) if entry.header.mode.anybits?(0o111)
        end
      end
    end
  end
end
