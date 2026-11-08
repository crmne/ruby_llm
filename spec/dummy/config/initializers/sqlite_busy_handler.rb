# frozen_string_literal: true

# Before Rails 8, SQLite waits for a lock through busy_timeout, which holds
# the GVL, so a claim heartbeat waiting on the run's own open transaction
# stops the process until the timeout. Rails 8 waits through
# busy_handler_timeout, which releases it between retries.
if ActiveRecord.version < Gem::Version.new('8.0')
  ActiveSupport.on_load(:active_record_sqlite3adapter) do
    prepend(Module.new do
      def configure_connection
        super
        timeout = @config[:timeout]
        return unless timeout && @raw_connection.respond_to?(:busy_handler_timeout=)

        @raw_connection.busy_handler_timeout = self.class.type_cast_config_to_integer(timeout)
      end
    end)
  end
end
