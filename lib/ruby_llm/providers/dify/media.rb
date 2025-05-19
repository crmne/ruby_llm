# frozen_string_literal: true

module RubyLLM
  module Providers
    module Dify
      # Media handling methods for the Gemini API integration
      module Media
        module_function

        def format_files(content)
          return nil unless content.is_a?(Content)
          
          parts = []

          content.attachments.each do |attachment|
            case attachment.type
            when :file_id
              parts << format_document_type(attachment)              
            else
              raise UnsupportedAttachmentError, attachment.class
            end
          end

          parts
        end

        def format_document_type(attachment)
          {
            type: 'document',
            transfer_method: 'local_file',
            upload_file_id: attachment.upload_file_id
          }
        end
      end
    end
  end
end
