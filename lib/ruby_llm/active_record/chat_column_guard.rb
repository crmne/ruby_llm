# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Refuses a chat table with a column, or a chat model with an
    # association, that a RubyLLM reader on the record would hide, such as
    # a +temperature+ column or a +tools+ association: reading it would
    # return RubyLLM's setting instead of the stored value. The check runs
    # when the class loads its columns, so it needs no database at boot. A
    # reader hides a column or an association when it comes from
    # ChatMethods or ChatFiles, or a module they bring along, such as
    # Enumerable.
    module ChatColumnGuard # :nodoc:
      OWNERS = (ChatMethods.ancestors | ChatFiles.ancestors).freeze

      private

      def load_schema!
        super
        hidden = columns_hash.keys.select { |column| hidden_by_ruby_llm?(column) }
        raise ArgumentError, hidden_columns_message(hidden) if hidden.any?

        associations = reflect_on_all_associations.select do |association|
          association.name.to_s != messages_association_name.to_s && hidden_by_ruby_llm?(association.name)
        end
        raise ArgumentError, hidden_associations_message(associations) if associations.any?
      end

      def hidden_by_ruby_llm?(name)
        method_defined?(name) && OWNERS.include?(instance_method(name).owner)
      end

      def hidden_columns_message(hidden)
        columns = hidden.map { |column| "#{table_name}.#{column}" }.join(', ')
        readers = hidden.map { |column| "#{name}##{column}" }.join(', ')
        them = hidden.one? ? 'it' : 'them'
        "#{columns} cannot be read on #{name}: acts_as_chat defines #{readers}, which would hide #{them}. " \
          "Rename the column in a migration, such as rename_column :#{table_name}, :#{hidden.first}, " \
          ":#{hidden.first}_setting."
      end

      def hidden_associations_message(associations)
        names = associations.map { |association| "#{association.macro} :#{association.name}" }.join(', ')
        readers = associations.map { |association| "#{name}##{association.name}" }.join(', ')
        them = associations.one? ? 'it' : 'them'
        "#{names} cannot be read on #{name}: acts_as_chat defines #{readers}, which would hide #{them}. " \
          "Rename #{them}, with class_name: and foreign_key: options that keep the same table and columns."
      end
    end
  end
end
