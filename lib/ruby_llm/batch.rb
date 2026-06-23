# frozen_string_literal: true

module RubyLLM
  # A provider-side batch of chat completions: chats awaiting a response go in
  # together, answers come back at batch prices, typically within hours.
  # Persist the id, reload from any process, and collect the messages once
  # processing ends.
  class Batch
    AWAITING_ROLES = %i[user tool].freeze

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
        payload = { provider: provider.slug, provider_class: provider.class.display_name, requests: chats.size }
        RubyLLM.instrument('batch.ruby_llm', payload, config: provider.config) do |event|
          requests = chats.each_with_index.map do |chat, index|
            { custom_id: index.to_s, model: chat.model.id, params: chat.render }
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
        raise Error, "#{provider.slug} doesn't support batch requests" unless provider.batches?

        new(provider:, **provider.find_batch(id))
      end

      private

      def awaiting_model?(chat)
        !chat.complete? && AWAITING_ROLES.include?(chat.messages.last&.role)
      end

      def shared_provider(chats)
        slugs = chats.map { |chat| chat.provider.slug }.uniq
        raise ArgumentError, "A batch takes one provider per submission, got: #{slugs.join(', ')}" if slugs.size > 1

        provider = chats.first.provider
        raise Error, "#{provider.slug} doesn't support batch requests" unless provider.batches?

        provider
      end
    end

    def initialize(provider:, chats: nil, batch_protocol: nil, **attributes)
      @provider = provider
      @chats = chats
      @batch_protocol = batch_protocol
      apply(attributes)
    end

    # Reloads from the provider until the batch ends, then caches.
    def complete?
      return true if @completed

      reload
      @completed
    end

    def reload
      apply(@provider.find_batch(id))
      self
    end

    def cancel
      apply(@provider.cancel_batch(id))
      self
    end

    # The answers in submission order, nil where a request failed, each also
    # appended to its chat. Cached only once the batch ends, so polling early
    # keeps reading fresh.
    def messages
      return @messages if @messages

      collected = collect_messages
      @messages = collected if @completed
      collected
    end

    private

    def apply(attributes)
      @id = attributes.fetch(:id)
      @status = attributes.fetch(:status)
      @completed = attributes.fetch(:completed)
      @request_counts = attributes[:request_counts]
      @batch_protocol = attributes[:batch_protocol] if attributes[:batch_protocol]
    end

    def collect_messages
      results = @provider.batch_results(id, batch_protocol: @batch_protocol)
      messages = Array.new(chats&.size || (results.map(&:first).max.to_i + 1))

      results.each do |index, message|
        messages[index] = message
        add_answer(chats&.[](index), message)
      end

      messages
    end

    def add_answer(chat, message)
      chat.add_completion(message) if message && chat && !already_in_chat?(chat, message)
    end

    # A plain answer is the chat's last message once it arrives. A tool-call
    # answer is not: running its tools adds messages after it, so we match on its
    # tool-call ids instead.
    def already_in_chat?(chat, message)
      if message.tool_call?
        chat.messages.any? { |m| m.tool_call? && m.tool_calls.keys.intersect?(message.tool_calls.keys) }
      else
        !AWAITING_ROLES.include?(chat.messages.last&.role)
      end
    end

    # Shared mechanics for provider-side batch APIs.
    module Helpers
      private

      def batch_result_index(id)
        Integer(id)
      end

      def batch_failure(custom_id, detail, status: 'failed')
        RubyLLM.logger.warn ["Batch request #{custom_id} #{status}", detail].compact.join(': ')
      end

      def batch_error_message(line)
        error = line['error']
        return error if error.is_a?(String)

        error&.dig('message') ||
          line['error_message'] ||
          line.dig('response', 'body', 'error', 'message') ||
          line.dig('response', 'error', 'message')
      end

      def single_batch_model!(requests, provider_name)
        models = requests.map { |request| request.fetch(:model) }.uniq
        return models.first if models.one?

        raise Error, "#{provider_name} batch requests must use one model per submission"
      end

      def batch_params(request, except: [])
        excluded = (Array(except) + [:stream]).map(&:to_s)
        request.fetch(:params).reject { |key, _| excluded.include?(key.to_s) }
      end
    end
  end
end
