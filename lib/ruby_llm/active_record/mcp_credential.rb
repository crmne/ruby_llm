# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # The OAuth state RubyLLM::MCP keeps for a server, in RubyLLM's
    # +ruby_llm_mcp_credentials+ table. +data+ is encrypted with Active
    # Record encryption, so the application needs encryption keys.
    #
    #   RubyLLM::ActiveRecord::MCPCredential.where(owner: current_user).pluck(:updated_at)
    #
    # Each row has an optional polymorphic +owner+, the record the
    # credentials were authorized for. Its columns:
    #
    # [+key+] The key RubyLLM stores the state under, unique across the table.
    # [+data+] Tokens, client registrations, and signing keys, as a Hash.
    #          Treat it as a secret.
    #
    # RubyLLM writes these rows. Read and query them, and add scopes or
    # columns of your own, but do not create, update, or delete them: call
    # +deauthorize+ on the server to forget a user's credentials.
    class MCPCredential < Record
      self.table_name = 'ruby_llm_mcp_credentials'

      belongs_to :owner, polymorphic: true, optional: true

      serialize :data, coder: JSON
      encrypts :data

      validates :key, presence: true

      class << self
        def read(key) # :nodoc:
          find_by(key:)&.data
        end

        def write(key, data, owner: nil) # :nodoc:
          attributes = { data:, owner: owner.is_a?(::ActiveRecord::Base) ? owner : nil }
          record = find_by(key:) || create_or_find_by!(key:) { |created| created.assign_attributes(attributes) }
          record.update!(attributes)
        end

        def delete(key) # :nodoc:
          where(key:).delete_all
        end

        # Updating the row locks it on every adapter; SQLite ignores FOR UPDATE.
        def synchronize(key) # :nodoc:
          transaction do
            where(key:).touch_all
            yield
          end
        end
      end
    end
  end
end
