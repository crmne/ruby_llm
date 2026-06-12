# frozen_string_literal: true

module RubyLLM
  # A provider-side batch of chat completions: chats awaiting a response go in
  # together, answers come back at batch prices, typically within hours.
  # Persist the id, reload from any process, and collect the messages once
  # processing ends.
  class Batch
    attr_reader :id, :status, :request_counts, :chats

    class << self
      def submit(chats)
        chats = chats.is_a?(Chat) ? [chats] : Array(chats)
        chats = chats.map { |chat| chat.respond_to?(:to_llm) ? chat.to_llm : chat }
        raise ArgumentError, 'Cannot submit an empty batch' if chats.empty?

        unless chats.all? { |chat| awaiting_model?(chat) }
          raise ArgumentError,
                'Every chat in a batch must be awaiting the model; stage one with ask_later, or run_tools first'
        end

        provider = shared_provider(chats)
        payload = { provider: provider.slug, provider_class: provider.class.name, requests: chats.size }
        RubyLLM.instrument('batch.ruby_llm', payload, config: provider.config) do |event|
          requests = chats.each_with_index.map do |chat, index|
            { custom_id: index.to_s, params: chat.render }
          end
          batch = new(provider:, chats:, **provider.create_batch(requests))
          event[:batch_id] = batch.id
          batch
        end
      end

      def find(id, provider:, context: nil)
        raise ArgumentError, 'Provider must be specified to find a batch' unless provider

        config = context&.config || RubyLLM.config
        provider = Provider.resolve!(provider).new(config)
        new(provider:, **provider.find_batch(id))
      end

      private

      # Ready for the model to respond: a staged question or run tool results
      # sit at the tail, with nothing left to run first.
      def awaiting_model?(chat)
        !chat.complete? && %i[user tool].include?(chat.messages.last&.role)
      end

      def shared_provider(chats)
        slugs = chats.map { |chat| chat.provider.slug }.uniq
        raise ArgumentError, "A batch takes one provider per submission, got: #{slugs.join(', ')}" if slugs.size > 1

        provider = chats.first.provider
        raise Error, "#{provider.slug} doesn't support batch requests" unless provider.batches?

        provider
      end
    end

    def initialize(provider:, chats: nil, **attributes)
      @provider = provider
      @chats = chats
      apply(**attributes)
    end

    # Whether the batch has finished processing. Reloads from the provider until
    # it ends, then caches; poll this in a loop and it stops hitting the network
    # once processing is done.
    def complete?
      return true if @completed

      reload
      @completed
    end

    def reload
      apply(**@provider.find_batch(id))
      self
    end

    def cancel
      apply(**@provider.cancel_batch(id))
      self
    end

    # The batch's messages, in submission order, nil where a request failed.
    # Each message is also appended to its chat when the chats are at hand.
    def messages
      @messages ||= collect_messages
    end

    private

    def apply(id:, status:, completed:, request_counts: nil)
      @id = id
      @status = status
      @completed = completed
      @request_counts = request_counts
    end

    def collect_messages
      results = @provider.batch_results(id)
      messages = Array.new(chats&.size || (results.map(&:first).max.to_i + 1))

      results.each do |index, message|
        messages[index] = message
        chats[index].add_completion(message) if chats && message
      end

      messages
    end
  end
end
