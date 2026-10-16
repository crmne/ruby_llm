# frozen_string_literal: true

require 'json'

module RubyLLM
  class Skill
    class Marketplace
      # A marketplace file: the marketplace's name and the plugins it lists,
      # in the shape Claude Code, Codex, and Cursor each write.
      class Catalog # :nodoc:
        FILES = %w[
          .claude-plugin/marketplace.json
          .agents/plugins/marketplace.json
          .cursor-plugin/marketplace.json
        ].freeze
        NAME = /\A[a-z0-9]+(?:[-._][a-z0-9]+)*\z/i
        GITHUB_URL = %r{\A(?:https://github\.com/|git@github\.com:)([\w.-]+/[\w.-]+?)(?:\.git)?/?\z}

        # +repository+ is +nil+ for a plugin inside the marketplace, and
        # +path+ is +nil+ when RubyLLM cannot fetch the plugin's source.
        Entry = Data.define(:name, :repository, :path, :skills) do
          def supported?
            !path.nil?
          end
        end

        attr_reader :name, :plugins

        def initialize(directory, source)
          @file = FILES.find { |file| directory.join(file).file? }
          invalid("#{source} has no marketplace file. Looked for #{FILES.join(', ')}") unless @file

          @label = "#{@file} in #{source}"
          data = parse(directory.join(@file))
          @name = name_of(data, 'the marketplace')
          @root = data.dig('metadata', 'pluginRoot').to_s
          @plugins = plugins_of(data)
        end

        def select(only)
          return plugins.select(&:supported?) if only.nil?

          Array(only).map { |name| named(name.to_s) }
        end

        private

        def parse(file)
          data = JSON.parse(file.read(encoding: 'UTF-8').delete_prefix("\u{FEFF}").scrub)
          invalid("#{@label} must hold a JSON object with a plugins array") unless
            data.is_a?(Hash) && data['plugins'].is_a?(Array) && data['plugins'].all?(Hash)
          data.merge('metadata' => data['metadata'].is_a?(Hash) ? data['metadata'] : {})
        rescue JSON::ParserError => e
          invalid("#{@label} is not valid JSON: #{e.message}")
        end

        def plugins_of(data)
          plugins = data['plugins'].map do |entry|
            skills = Array(entry['skills']).grep(String)
            Entry.new(name: name_of(entry, 'a plugin'), skills:, **source(entry['source']))
          end
          repeated = plugins.map(&:name).tally.select { |_name, count| count > 1 }.keys
          invalid("#{@label} lists #{repeated.join(', ')} more than once") if repeated.any?
          plugins
        end

        def name_of(entry, subject)
          name = entry['name'].to_s
          return name if name.match?(NAME) && name != RECORD

          invalid("#{@label} names #{subject} #{name.inspect}; names are letters and digits joined by - . or _")
        end

        def source(source)
          case source
          when String then relative(source)
          when Hash then described(source)
          else unsupported
          end
        end

        def described(source)
          case source['source']
          when nil, 'local' then source['path'].is_a?(String) ? relative(source['path']) : unsupported
          when 'github' then github(source['repo'], source)
          when 'url' then github(source['url'].to_s[GITHUB_URL, 1], source)
          when 'git-subdir' then github(source['url'].to_s[GITHUB_URL, 1], source, path: source['path'].to_s)
          else unsupported
          end
        end

        def relative(path)
          path = File.join(@root, path) unless @root.empty? || path.start_with?('.')
          { repository: nil, path: }
        end

        def github(name, source, path: '')
          ref = source['sha'] || source['ref']
          repository = [name, ref].compact.join('@')
          (ref.nil? || ref.is_a?(String)) && Repository.github?(repository) ? { repository:, path: } : unsupported
        end

        def unsupported
          { repository: nil, path: nil }
        end

        def named(name)
          plugin = plugins.find { |candidate| candidate.name == name }
          unless plugin
            raise ArgumentError, "#{@name} has no plugin named #{name}. Plugins: #{plugins.map(&:name).join(', ')}"
          end
          raise ArgumentError, "RubyLLM cannot fetch the source of the #{name} plugin" unless plugin.supported?

          plugin
        end

        def invalid(reason)
          raise InvalidMarketplaceError, reason
        end
      end
    end
  end
end
