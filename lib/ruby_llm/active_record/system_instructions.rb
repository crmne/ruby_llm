# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Compares the system messages a chat record persisted with the
    # instructions about to be applied to it.
    module SystemInstructions # :nodoc:
      # Returns whether the persisted system messages are exactly
      # +instructions+, pairs of content and +cache_until_here+ in order.
      # An agent applied to a record on every request asks before it
      # rewrites them.
      def system_instructions_persisted?(instructions)
        records = messages_association.where(role: :system).order(:id).to_a
        records.size == instructions.size && records.zip(instructions).all? do |record, (content, cache_until_here)|
          system_instruction_attributes(record, content, cache_until_here).all? do |column, value|
            record[column] == value
          end
        end
      end

      private

      def system_instruction_attributes(record, instructions, cache_until_here)
        boundary = cache_boundary_attributes(cache_until_here)
        boundary.delete(:cache_until_here) unless record.has_attribute?(:cache_until_here)
        { content: instructions, **boundary }
      end
    end
  end
end
