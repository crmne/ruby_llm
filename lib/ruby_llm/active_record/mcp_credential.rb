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
          record = find_or_initialize_by(key:)
          record.update!(data:, owner: owner.is_a?(::ActiveRecord::Base) ? owner : nil)
        end

        def delete(key)
          where(key:).delete_all
        end
      end
    end
  end
end
