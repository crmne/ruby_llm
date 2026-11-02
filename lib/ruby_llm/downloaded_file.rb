# frozen_string_literal: true

module RubyLLM
  # A DownloadedFile contains a provider file's bytes. Save it with #save
  # or read the bytes with #to_blob. It is also a String, so parsers and
  # existing string operations work directly on the result.
  #
  #   RubyLLM.download(file.id, provider: :openai).save("report.pdf")
  #
  class DownloadedFile < String
    include Support::Inspectable
    include Files::Saving

    ##
    # :method: save
    # :call-seq:
    #   save(path)
    #
    # Writes the file bytes to +path+, expanding it first. Returns +path+.
    #
    #   file.save("report.pdf")

    # Returns the raw file bytes as a String.
    def to_blob
      to_s
    end

    private

    def inspect_attributes # :nodoc:
      { byte_size: bytesize }
    end
  end
end
