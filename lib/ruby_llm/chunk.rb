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
  end
end
