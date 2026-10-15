# frozen_string_literal: true

module RubyLLM
  # A Chunk is one streamed fragment of an assistant response. Chunks are
  # yielded to the block passed to Chat#ask or Chat#complete when streaming.
  # A Chunk is a Message, so it responds to the same readers, but it holds
  # only the data received in that part of the stream, such as a piece of
  # content, partial tool calls, or the finish reason on the final chunk.
  #
  #   chat.ask "Write a haiku about Ruby" do |chunk|
  #     print chunk.content
  #   end
  #
  class Chunk < Message
    # Returns the position of this chunk within the response it belongs
    # to, starting at 0. Each response in a Chat#complete loop, such as
    # the one after a tool call, starts again at 0. Counts every chunk,
    # including those without content.
    #
    #   chat.ask("Count to three") { |chunk| puts "#{chunk.index}: #{chunk.content}" }
    #
    attr_accessor :index
  end
end
