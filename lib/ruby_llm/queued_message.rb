# frozen_string_literal: true

require 'securerandom'

module RubyLLM
  # A user message waiting to join a conversation, from Chat#queue. The
  # conversation loop takes it between two of its moves, where it becomes
  # an ordinary user Message.
  #
  #   queued = chat.queue "Use the EU file instead"
  #   chat.queued_messages # => [#<RubyLLM::QueuedMessage ...>]
  #   chat.unqueue(queued) # => true
  #
  class QueuedMessage
    include Support::Inspectable

    # A String that identifies this message among the chat's queued ones.
    attr_reader :id

    # The text of the message, as given to Chat#queue.
    attr_reader :content

    # The attachments given with +with:+, or +nil+.
    attr_reader :attachments

    # Whoever queued the message, as given with +owner:+, or +nil+.
    # RubyLLM stores it and hands it back without interpreting it.
    attr_reader :owner

    # The Time the message was queued.
    attr_reader :queued_at

    def initialize(content:, attachments: nil, steer: true, owner: nil) # :nodoc:
      @id = SecureRandom.uuid
      @content = content
      @attachments = attachments
      @steer = steer
      @owner = owner
      @queued_at = Time.now
    end

    # Returns whether the message steers the turn that is running, joining
    # it at the next step, rather than waiting for the turn to end.
    def steer?
      @steer
    end

    private

    def inspect_attributes
      { id:, content:, steer: steer? }
    end
  end
end
