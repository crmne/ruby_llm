# frozen_string_literal: true

module RubyLLM
  class FileStore
    module Tools
      # What the file tools share: the chat's store, its configuration,
      # the callback for each file a tool writes, and the check that the
      # model read a file before it changes it.
      class Base < Tool # :nodoc:
        class ToolError < StandardError; end # :nodoc:

        inline_limit false

        def initialize(store:, config: -> { RubyLLM.config }, written: ->(_file) {})
          super()
          @store = store
          @config = config
          @written = written
        end

        private

        def store
          @store.call
        end

        def config
          @config.call
        end

        def path_for(name)
          FileStore.path(name)
        rescue ArgumentError => e
          raise ToolError, e.message
        end

        def folder_for(name)
          path_for(name) unless name.to_s.strip.empty? || %w[. /].include?(name.to_s.strip)
        end

        def file_at(name)
          path = path_for(name)
          store[path] || raise(ToolError, "There is no file at #{path}. #{missing_hint(path)}")
        end

        def missing_hint(path)
          folder = store.list(path).first
          return "#{path} is a folder: list it with list_files." if folder

          'List the files with list_files.'
        end

        def digest_of(file)
          file.digest || FileStore.digest(store.read(file.path))
        end

        # Yields the file at +path+, or +nil+ for a new one, with the store
        # locked, once the model has read the file as it is now.
        def changing(path)
          store.with_lock do
            file = store[path]
            fresh!(file) if file
            yield file
          end
        end

        def fresh!(file)
          seen = store.read_digest(file.path)
          raise ToolError, "Read #{file.path} before you change it." unless seen
          return if seen == digest_of(file)

          raise ToolError, "#{file.path} changed since you read it. Read it again."
        end

        def guarded_write
          written = []
          result = guarded do
            yield(lambda do |path, content|
              file = store.write(path, content)
              store.record_read(file.path, file.digest || FileStore.digest(content))
              written << file
              file
            end)
          end
          written.each { |file| @written.call(file) }
          result
        end

        def guarded
          yield
        rescue ToolError, FileStoreFullError, ArgumentError => e
          { error: e.message }
        rescue SystemCallError => e
          { error: SystemCallError.new(e.errno).message }
        end
      end
    end
  end
end
