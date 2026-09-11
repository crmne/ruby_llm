# frozen_string_literal: true

require_relative 'upgrade_migration'
require_relative 'online_copy_migration/journal'
require_relative 'online_copy_migration/data'

module RubyLLM
  module Generators
    class OnlineCopyMigration < UpgradeMigration # :nodoc: all
      def online? = true

      def prepare(settings)
        with_migration_lock do
          super(settings.merge(online: true), &nil)
          unless @connection.column_exists?(TABLE, :epoch)
            @connection.add_column(TABLE, :epoch, :bigint, null: false, default: 0)
          end
          yield if block_given?
          data.prepare
          journal.install
        end
      end

      def verify_settings(settings)
        super(settings.merge(online: true))
      end

      def copy_table(source, target)
        create_copy_table(source, target) unless @connection.table_exists?(target)
      end

      def copy_model_references
        nil
      end

      def backfill
        with_migration_lock do
          state = states.first!
          unless state.active_version == 1 && %w[preparing active].include?(state.status)
            raise 'Online copy backfill requires RubyLLM 1.16 to be active'
          end
          raise 'Use resume after rolling back a finished upgrade' if data.finished?

          data.backfill
          data.catch_up(passes: 2)
          state.update!(needs_reconcile: false)
        end
      end

      def finish
        with_migration_lock do
          state = states.first!
          return if state.active_version == 2 && state.status == 'active' && data.finished?

          raise 'Run the copy backfill before finish' unless data.completed?

          pause(state, from: 1, statuses: %w[preparing active finishing])
          data.catch_up
          data.verify
          verify_completed_work
          yield
          journal.install
          state.update!(active_version: 2, status: 'active', needs_reconcile: false)
        end
      end

      def rollback
        with_migration_lock do
          state = states.first!
          unless data.finished?
            raise 'The unfinished upgrade is not running on 1.16' unless state.active_version == 1

            state.update!(status: 'preparing', needs_reconcile: true)
            return
          end
          state.with_lock do
            require_active_version(state, 2)
            verify_completed_work
            state.update!(active_version: 1, epoch: state.epoch + 1)
          end
        end
      end

      def resume
        with_migration_lock do
          raise 'Finish the initial copy migrations before resuming 2.0' unless data.finished?

          state = states.first!
          pause(state, from: 1, statuses: %w[active finishing])
          data.catch_up
          data.verify
          verify_completed_work
          state.update!(active_version: 2, status: 'active', needs_reconcile: false)
        end
      end

      def finalize
        with_migration_lock { super }
      end

      def cleanup
        with_migration_lock do
          verify_cleanup
          journal.remove
          yield if block_given?
          data.cleanup
          super
        end
      end

      private

      def pause(state, from:, statuses:)
        state.with_lock do
          unless state.active_version == from && statuses.include?(state.status)
            raise 'The copy upgrade is not ready for this version switch'
          end

          state.update!(status: 'finishing', epoch: state.epoch + 1) unless state.status == 'finishing'
        end
      end

      def data
        @data ||= Data.new(connection: @connection, settings: configuration)
      end

      def journal
        @journal ||= Journal.new(connection: @connection, settings: configuration)
      end

      def with_migration_lock(&)
        return with_mysql_lock(&) if @connection.adapter_name == 'Mysql2'
        return with_sqlite_lock(&) if @connection.adapter_name == 'SQLite'

        key = "hashtextextended(current_database() || '.' || current_schema() || '.ruby_llm_upgrade', 0)"
        locked = @connection.select_value("SELECT pg_try_advisory_lock(#{key})")
        raise 'Another RubyLLM copy migration is running' unless locked

        begin
          yield
        ensure
          @connection.execute("SELECT pg_advisory_unlock(#{key})")
        end
      end

      def with_mysql_lock
        key = @connection.quote("ruby_llm_upgrade:#{@connection.current_database}".slice(0, 64))
        locked = @connection.select_value("SELECT GET_LOCK(#{key}, 0)")
        raise 'Another RubyLLM copy migration is running' unless locked == 1

        begin
          yield
        ensure
          @connection.execute("SELECT RELEASE_LOCK(#{key})")
        end
      end

      def with_sqlite_lock
        database = @connection.pool.db_config.database
        return yield if database == ':memory:'

        File.open("#{database}.ruby_llm_upgrade.lock", File::RDWR | File::CREAT, 0o600) do |file|
          raise 'Another RubyLLM copy migration is running' unless file.flock(File::LOCK_EX | File::LOCK_NB)

          yield
        end
      end
    end
  end
end
