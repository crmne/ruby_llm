# frozen_string_literal: true

module RubyLLM
  class FileStore
    # The tools Chat#with_file_store gives the model, by the names its
    # +tools:+ option takes: +:read+ for +list_files+, +read_file+, and
    # +search_files+, +:write+ for +write_file+, +:edit+ for +edit_file+,
    # and +:delete+ for +delete_file+.
    module Tools # :nodoc:
      GROUPS = { read: %i[List Read Search], write: %i[Write], edit: %i[Edit], delete: %i[Delete] }.freeze
      DEFAULT = %i[read write edit].freeze

      class << self
        # Returns +tools+, a name or an Array of them, as Symbols in the
        # order of GROUPS. Raises ArgumentError for a name it does not know,
        # and without +:read+.
        def names(tools)
          names = Array(tools).map { |name| name.to_s.to_sym }
          unknown = names - GROUPS.keys
          if unknown.any?
            raise ArgumentError,
                  "tools: takes :read, :write, :edit, and :delete, got #{unknown.map(&:inspect).join(', ')}"
          end
          unless names.include?(:read)
            raise ArgumentError,
                  'tools: needs :read, since the model reads its files with it'
          end

          GROUPS.keys & names
        end

        # Returns the tool classes for +names+.
        def classes(names)
          names.flat_map { |name| GROUPS.fetch(name) }.map { |name| const_get(name) }
        end
      end
    end
  end
end
