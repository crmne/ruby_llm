# frozen_string_literal: true

module RubyLLM
  module Attachments
    # Represents a PDF attachment
    class PDF < Base
      def mime_type
        'application/pdf'
      end
    end
  end
end
