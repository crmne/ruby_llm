# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # RubyLLM's persistence for MCP OAuth credentials, encrypted with Active
    # Record encryption.
    class MCPCredential < Record # :nodoc:
      self.table_name = 'ruby_llm_mcp_credentials'

      belongs_to :owner, polymorphic: true, optional: true

      serialize :data, coder: JSON
      encrypts :data

      validates :key, presence: true

      class << self
        def read(key)
          find_by(key:)&.data
        end

        def write(key, data, owner: nil)
          attributes = { data:, owner: owner.is_a?(::ActiveRecord::Base) ? owner : nil }
          record = find_by(key:) || create_or_find_by!(key:) { |created| created.assign_attributes(attributes) }
          record.update!(attributes)
        end

        def delete(key)
          where(key:).delete_all
        end

        # Updating the row locks it on every adapter; SQLite ignores FOR UPDATE.
        def synchronize(key)
          transaction do
            where(key:).touch_all
            yield
          end
        end
      end
    end
  end
end
