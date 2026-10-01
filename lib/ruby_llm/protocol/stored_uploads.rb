# frozen_string_literal: true

module RubyLLM
  class Protocol
    # Reuses the provider file an attachment's store recorded in an earlier
    # process. Before a process first reuses a file, the provider confirms
    # it still has it; a file that is missing or expired is uploaded again.
    class StoredUploads # :nodoc:
      FILES = Support::ProcessCache.new(limit: 1024)

      def self.files
        FILES
      end

      def initialize(provider, store)
        @provider = provider
        @store = store
        @account = provider.account_identity if store
      end

      def fetch
        return yield unless @account

        stored_file || remember(yield)
      end

      def forget(upload)
        return unless @account

        FILES.delete(key(upload.id))
        @store.forget(upload.id, provider: @provider.slug, account: @account)
      end

      private

      def stored_file
        stored = @store.fetch(provider: @provider.slug, account: @account)
        return if stored.nil? || stored.expired?

        file = confirmed_file(stored.id)
        file unless file.nil? || file.expired?
      end

      def confirmed_file(id)
        FILES.fetch(key(id)) { @provider.find_file(id) }
      rescue StandardError => e
        RubyLLM.logger.debug { "Uploading again: #{@provider.slug} could not find #{id} (#{e.message})" }
        nil
      end

      def remember(upload)
        FILES.fetch(key(upload.id)) { upload }
        @store.store(upload, provider: @provider.slug, account: @account)
        upload
      end

      def key(id)
        [@provider.slug, @account, id]
      end
    end
  end
end
