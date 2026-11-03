# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Abstract base for the records of the tables RubyLLM owns: Model,
    # ToolCall, Usage, Batch, MCPCredential, ProviderFile, QueuedMessage,
    # and ChatFile.
    # Inherits the application's default connection unless configured otherwise.
    # Keep these records on the same database and connection pool as chats and
    # messages to preserve foreign keys and shared transactions.
    #
    #   Rails.application.config.to_prepare do
    #     RubyLLM::ActiveRecord::Record.connection_specification_name =
    #       LlmRecord.connection_specification_name
    #   end
    #
    class Record < ::ActiveRecord::Base
      self.abstract_class = true
    end
  end
end
