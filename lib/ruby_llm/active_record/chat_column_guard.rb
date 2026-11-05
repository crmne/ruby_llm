# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Refuses a chat table with a column that a RubyLLM reader on the record
    # would hide, such as +temperature+ or +cost+: reading it would return
    # RubyLLM's setting instead of the stored value. The check runs when the
    # class loads its columns, so it needs no database at boot. A reader
    # hides a column when it comes from ChatMethods or ChatFiles, or a
    # module they bring along, such as Enumerable.
    module ChatColumnGuard # :nodoc:
      OWNERS = (ChatMethods.ancestors | ChatFiles.ancestors).freeze

      private

      def load_schema!
        super
        hidden = columns_hash.keys.select do |column|
          method_defined?(column) && OWNERS.include?(instance_method(column).owner)
        end
        raise ArgumentError, hidden_columns_message(hidden) if hidden.any?
      end

      def hidden_columns_message(hidden)
        columns = hidden.map { |column| "#{table_name}.#{column}" }.join(', ')
        readers = hidden.map { |column| "#{name}##{column}" }.join(', ')
        them = hidden.one? ? 'it' : 'them'
        "#{columns} cannot be read on #{name}: acts_as_chat defines #{readers}, which would hide #{them}. " \
          "Rename the column in a migration, such as rename_column :#{table_name}, :#{hidden.first}, " \
          ":#{hidden.first}_setting."
      end
    end
  end
end
