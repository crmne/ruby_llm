# frozen_string_literal: true

module RubyLLM
  class FileStore
    module Tools
      # What the five file tools share: the chat's store, its
      # configuration, and the callback for each file a tool writes.
      class Base < Tool # :nodoc:
        class ToolError < StandardError; end # :nodoc:

        spill_to_file false

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

        def file_at(name)
          path = path_for(name)
          store.find(path) || raise(ToolError, "There is no file at #{path}. #{missing_hint(path)}")
        end

        def missing_hint(path)
          folder = store.list(path).first
          return "#{path} is a folder: list it with list_files." if folder

          'List the files with list_files.'
        end

        def write(path, content)
          store.write(path, content).tap { |file| @written.call(file) }
        end

        def guarded
          yield
        rescue ToolError => e
          { error: e.message }
        end
      end
    end
  end
end
