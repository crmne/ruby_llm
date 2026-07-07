# frozen_string_literal: true

module RubyLLM
  class Model
    # A Model::Modalities lists the kinds of content a model accepts and
    # produces, as arrays of Strings. Instances come from Model#modalities.
    #
    #   model = RubyLLM.models.find('gpt-5.4')
    #   model.modalities.input   # => ["text", "image", "pdf"]
    #   model.modalities.output  # => ["text"]
    #
    class Modalities
      # The input modalities as an array of Strings,
      # e.g. <tt>["text", "image", "pdf"]</tt>.
      attr_reader :input

      # The output modalities as an array of Strings,
      # e.g. <tt>["text"]</tt> or <tt>["embeddings"]</tt>.
      attr_reader :output

      def initialize(data) # :nodoc:
        @input = Array(data[:input]).map(&:to_s)
        @output = Array(data[:output]).map(&:to_s)
      end

      # Returns the modalities as a Hash with +:input+ and +:output+ keys.
      def to_h
        {
          input: input,
          output: output
        }
      end
    end
  end
end
