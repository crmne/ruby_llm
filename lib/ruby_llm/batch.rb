# frozen_string_literal: true

module RubyLLM
  # A Batch is a provider-side batch of chat completions: chats awaiting a
  # response go in together, answers come back at batch prices, typically
  # within hours. Persist the id, pick the batch back up from any process,
  # and collect the messages once processing ends.
  #
  #   chats = documents.map do |doc|
  #     RubyLLM.chat(model: "claude-haiku-4-5").ask_later(doc.text)
  #   end
  #   batch = RubyLLM.batch(chats)
  #   batch.id                # => "msgbatch_01EhcDuvb5XfWqcdJArbsfNX"
  #   batch.refresh.complete? # => false, check back later
  #   batch.messages          # the responses, in submission order
  #
  class Batch
    AWAITING_ROLES = %i[user tool].freeze # :nodoc:

    # The provider's batch id. Persist it to load the batch again later
    # from any process with ::find.
    attr_reader :id

    # The provider-reported status string, such as "in_progress".
    # Refreshed by #refresh.
    attr_reader :status

    # The provider-reported request tallies by state, or +nil+ when the
    # provider does not report them.
    attr_reader :request_counts

    # The submitted Chat objects in order, or +nil+ when the batch was
    # loaded by id via ::find.
    attr_reader :chats

    class << self
      # Submits +chats+ to their shared provider as a batch and returns a
      # new Batch. Accepts a single Chat or an array. Every chat must be
      # awaiting the model (see Chat#ask_later), and all must use the same
      # provider.
      #
      #   chats = tickets.map do |ticket|
      #     RubyLLM.chat(model: "claude-haiku-4-5").ask_later(ticket.body)
      #   end
      #   batch = RubyLLM::Batch.submit(chats)
      #   batch.status # => "in_progress"
      #
      # Raises ArgumentError if +chats+ is empty, mixes providers, or
      # includes a chat that is not awaiting the model.
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
            { custom_id: index.to_s, model: chat.model.id, payload: chat.render }
          end
          batch = new(provider:, chats:, **provider.create_batch(requests))
          event[:batch_id] = batch.id
          batch
        end
      end

      # Returns a Batch reflecting the provider's current state for +id+.
      # Use it to pick a batch back up from any process.
      #
      #   batch = RubyLLM::Batch.find("msgbatch_01EhcDuvb5XfWqcdJArbsfNX",
      #                               provider: :anthropic)
      #   batch.complete? # => true
      #
      # Pass +context:+ to use a Context in place of the global
      # configuration. Raises ArgumentError if +provider+ is not given.
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

    def initialize(provider:, chats: nil, batch_protocol: nil, **attributes) # :nodoc:
      @provider = provider
      @chats = chats
      @batch_protocol = batch_protocol
      apply(attributes)
    end

    # Returns whether the batch has finished processing, as of the last
    # state fetched from the provider. Never contacts the provider; poll
    # with #refresh.
    #
    #   sleep 60 until batch.refresh.complete?
    #
    def complete?
      @completed
    end

    # Re-fetches the batch from the provider, updating #status,
    # #request_counts, and #complete?. Returns +self+.
    def refresh
      apply(@provider.find_batch(id))
      self
    end

    # Asks the provider to cancel the batch and applies the new state.
    # Requests already processed still return results. Returns +self+.
    def cancel
      apply(@provider.cancel_batch(id))
      self
    end

    # Returns the answers in submission order, +nil+ where a request
    # failed, each also appended to its chat. Fetches results from the
    # provider; cached once #complete? is true, so collecting early
    # keeps reading fresh.
    #
    #   batch.messages.each do |message|
    #     puts message.content
    #   end
    #
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

    module Helpers # :nodoc:
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

      def batch_payload(request, except: [])
        excluded = (Array(except) + [:stream]).map(&:to_s)
        request.fetch(:payload).reject { |key, _| excluded.include?(key.to_s) }
      end
    end
  end
end
