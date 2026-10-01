# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # RubyLLM's record of the provider files each Active Storage blob was
    # uploaded to, so a chat loaded in another process sends the file it
    # already uploaded instead of uploading the blob again. Rows name the
    # blob by its key, which Active Storage never hands out twice, so a row
    # left by a deleted blob can never match a newer one.
    class ProviderFile < Record # :nodoc:
      self.table_name = 'ruby_llm_provider_files'

      validates :blob_key, :provider, :account, :file_id, presence: true

      # Returns a store for the blob whose key the block returns, or +nil+
      # while the table has not been migrated.
      def self.store(&)
        Store.new(&) if table_exists?
      end

      # Deletes the uploads recorded for +blob+ as Active Storage destroys it.
      def self.forget_blob(blob)
        where(blob_key: blob.key).delete_all if table_exists?
      end

      # The uploads of one blob. The block finds the blob the first time a
      # provider asks, so attachments that are never uploaded cost nothing.
      class Store # :nodoc:
        def initialize(&blob_key)
          @find_blob_key = blob_key
        end

        def fetch(provider:, account:)
          record = blob_key && ProviderFile.find_by(blob_key:, provider:, account:)
          RubyLLM::UploadedFile.new(id: record.file_id, provider:, expires_at: record.expires_at) if record
        end

        # Another process can record an upload of the same blob first; its
        # file serves as well as this one.
        def store(upload, provider:, account:)
          return unless blob_key

          ProviderFile.find_or_initialize_by(blob_key:, provider:, account:)
                      .update!(file_id: upload.id, expires_at: upload.expires_at)
        rescue ::ActiveRecord::RecordNotUnique
          nil
        end

        # Only a row that still names the missing file goes: another process
        # may have recorded a newer upload meanwhile.
        def forget(id, provider:, account:)
          ProviderFile.where(blob_key:, provider:, account:, file_id: id).delete_all if blob_key
        end

        private

        def blob_key
          @blob_key = @find_blob_key.call unless defined?(@blob_key)
          @blob_key
        end
      end
    end
  end
end
