# frozen_string_literal: true

module RubyLLM
  # A Batch is a provider-side batch of requests: chats awaiting a
  # response (or texts awaiting embeddings) go in together, answers come
  # back at batch prices, typically within hours. Persist the id, pick the
  # batch back up from any process, and collect the results once
  # processing ends.
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
    include Inspectable

    AWAITING_ROLES = %i[user tool].freeze # :nodoc:

    # The provider's batch id. Persist it to load the batch again later
    # from any process with ::find.
    attr_reader :id

    # The provider-neutral lifecycle status: +:pending+, +:succeeded+,
    # +:failed+, or +:cancelled+. Refreshed by #refresh.
    attr_reader :status

    # The provider-reported status string, such as "in_progress".
    # Refreshed by #refresh.
    attr_reader :raw_status

    # The provider-reported request tallies by state, or +nil+ when the
    # provider does not report them.
    attr_reader :request_counts

    # The submitted Chat objects in order, or +nil+ when the batch was
    # loaded by id via ::find or holds embedding requests.
    attr_reader :chats

    # The submitted EmbeddingRequest objects in order, or +nil+ when the
    # batch was loaded by id via ::find or holds chats.
    attr_reader :requests

    # The normalized outcome of each collected request, in submission order.
    # Values are +:succeeded+, +:failed+, or +:cancelled+.
    attr_reader :statuses

    class << self
      # Submits chats or embedding requests to their shared provider as a
      # batch and returns a new Batch. Accepts a single Chat or an array.
      # Every chat must be awaiting the model (see Chat#ask_later), and all
      # requests must use the same provider.
      #
      #   chats = tickets.map do |ticket|
      #     RubyLLM.chat(model: "claude-haiku-4-5").ask_later(ticket.body)
      #   end
      #   batch = RubyLLM::Batch.submit(chats)
      #   batch.status     # => :pending
      #   batch.raw_status # => "in_progress"
      #
      # Raises ArgumentError if the batch is empty, mixes providers, mixes
      # chats with embedding requests, or includes a chat that is not
      # awaiting the model.
      def submit(chats)
        records = wrap_records(chats)
        return submit_embeddings(records) if records.any?(EmbeddingRequest)

        submit_chats(records)
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
      def find(id, provider: nil, context: nil)
        config = context&.config || RubyLLM.config
        persisted = config.batch_store&.fetch(id, provider:, context:)
        return persisted if persisted

        unless provider
          raise ArgumentError, 'Provider must be specified to find a batch that is not persisted by RubyLLM'
        end

        provider = Provider.resolve!(provider).new(config)
        raise Error, "#{provider.slug} doesn't support batch requests" unless provider.batches?

        new(provider:, store: config.batch_store, **provider.find_batch(id))
      end

      private

      def submit_chats(records)
        chats = normalize_chats(records)

        provider = shared_provider(chats)
        payload = { provider: provider.slug, provider_class: provider.class.display_name, requests: chats.size }
        RubyLLM.instrument('batch.ruby_llm', payload, config: provider.config) do |event|
          requests = chats.each_with_index.map do |chat, index|
            { custom_id: index.to_s, model: chat.model.id, payload: chat.render }
          end
          store = provider.config.batch_store
          batch = new(provider:, chats:, store:, **provider.create_batch(requests))
          store&.persist(batch, records)
          event[:batch_id] = batch.id
          batch
        end
      end

      def submit_embeddings(requests)
        unless requests.all?(EmbeddingRequest)
          raise ArgumentError, 'A batch takes chats or embedding requests, not both'
        end

        provider = shared_provider(requests)
        payload = { provider: provider.slug, provider_class: provider.class.display_name, requests: requests.size }
        RubyLLM.instrument('batch.ruby_llm', payload, config: provider.config) do |event|
          lines = requests.each_with_index.map do |request, index|
            { custom_id: index.to_s, model: request.model.id, payload: request.render }
          end
          batch = new(provider:, requests:, store: provider.config.batch_store, **provider.create_batch(lines))
          event[:batch_id] = batch.id
          batch
        end
      end

      def wrap_records(records)
        case records
        when Chat, EmbeddingRequest then [records]
        else Array(records)
        end
      end

      def normalize_chats(records)
        normalized = records.map { |chat| chat.respond_to?(:to_llm) ? chat.to_llm : chat }
        raise ArgumentError, 'Cannot submit an empty batch' if normalized.empty?

        unless normalized.all? { |chat| awaiting_model?(chat) }
          raise ArgumentError,
                'Every chat in a batch must be awaiting the model; stage one with ask_later, or run_tools first'
        end

        normalized
      end

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

    def initialize(provider:, chats: nil, requests: nil, batch_protocol: nil, store: nil, **attributes) # :nodoc:
      @provider = provider
      @chats = chats
      @requests = requests
      @batch_protocol = protocol_name(batch_protocol)
      @store = store
      @delivered = {}
      @statuses = []
      apply(attributes)
    end

    # The slug of the provider running the batch, as a String.
    def provider
      @provider.slug
    end

    attr_reader :batch_protocol # :nodoc:

    # Returns whether the batch has finished processing, as of the last
    # state fetched from the provider. Never contacts the provider; poll
    # with #refresh.
    #
    #   sleep 60 until batch.refresh.complete?
    #
    def complete?
      @completed
    end

    # Returns whether the provider completed the batch successfully.
    def succeeded?
      status == :succeeded
    end

    # Returns whether the provider failed or expired the batch.
    def failed?
      status == :failed
    end

    # Returns whether the provider cancelled the batch.
    def cancelled?
      status == :cancelled
    end

    # Re-fetches the batch from the provider, updating #status, #raw_status,
    # #request_counts, and #complete?. Returns +self+.
    def refresh
      apply(@provider.find_batch(id))
      persist_state
      self
    end

    # Asks the provider to cancel the batch and applies the new state.
    # Requests already processed still return results. Returns +self+.
    def cancel
      apply(@provider.cancel_batch(id))
      persist_state
      self
    end

    # Returns the answers in submission order, +nil+ where a request
    # failed. In a chat batch the answers are Messages, each also appended
    # to its chat; in an embeddings batch they are Embeddings, each also
    # hydrated into its request's EmbeddingRequest#result. Fetches results
    # from the provider; cached once #complete? is true, so collecting
    # early keeps reading fresh.
    #
    #   batch.messages.each do |message|
    #     puts message.content
    #   end
    #
    def messages
      return @messages if @messages

      collected = collect_results
      @messages = collected if @completed
      collected
    end

    alias results messages

    # Returns token usage aggregated across the batch's collected responses.
    def tokens
      Tokens.aggregate(messages.compact.map(&:tokens))
    end

    # Returns cost aggregated across the batch's collected responses.
    def cost
      Cost.aggregate(messages.compact.map(&:cost))
    end

    private

    def persist_state
      @store&.sync(self)
    end

    def apply(attributes)
      @batch_protocol = protocol_name(attributes[:batch_protocol]) if attributes[:batch_protocol]
      @id = attributes.fetch(:id)
      @raw_status = attributes.fetch(:raw_status)
      @completed = attributes.fetch(:completed)
      @request_counts = attributes[:request_counts]
      @request_count = attributes[:request_count]
      @status = @provider.batch_status(@raw_status, completed: @completed, batch_protocol: @batch_protocol)
    end

    def protocol_name(protocol)
      return if protocol.nil?

      protocol.is_a?(Module) ? @provider.batch_protocol_name(protocol) : protocol.to_s
    end

    def collect_results
      results = @provider.batch_results(id, batch_protocol: @batch_protocol)
      slots = Array.new(result_slot_count(results))

      results.each do |index, result, failure_status|
        slots[index] = result
        deliver(index, result, failure_status)
      end

      fill_missing_statuses(slots.size) if complete?

      slots
    end

    def result_slot_count(results)
      chats&.size || requests&.size || @request_count || ((results.map(&:first).max || -1) + 1)
    end

    def fill_missing_statuses(size)
      missing_status = cancelled? ? :cancelled : :failed
      size.times { |index| statuses[index] ||= missing_status }
    end

    # Collecting early keeps reading fresh, so a result already delivered
    # comes back on every later poll: hand each one over once.
    def deliver(index, result, failure_status)
      statuses[index] = result ? :succeeded : failure_status
      return unless result

      if result.is_a?(Embedding)
        deliver_embedding(index, result)
      else
        deliver_message(index, result)
      end
    end

    def deliver_embedding(index, embedding)
      request = requests&.[](index)
      delivered = @delivered[index]
      attach_batch_usage(
        embedding,
        operation: :embedding,
        model: request&.model,
        category: :embeddings,
        instrument: !request.nil? && !delivered
      )
      return if delivered

      @delivered[index] = true
      request&.result = embedding
    end

    def deliver_message(index, message)
      chat = chats&.[](index)
      delivered = @delivered[index] || (chat && already_in_chat?(chat, message))
      attach_batch_usage(
        message,
        operation: :chat,
        model: chat&.model,
        category: :text_tokens,
        instrument: !chat.nil? && !delivered
      )
      return if delivered

      @delivered[index] = true
      chat&.add_completion(message, record_usage: true)
    end

    def attach_batch_usage(result, operation:, model:, category:, instrument:)
      return unless result.ruby_llm_usage_entries.empty?

      model ||= RubyLLM.models.find(result.model, provider: @provider.slug, config: @provider.config)
      entry = Usage::Entry.new(
        operation:,
        provider: @provider.slug,
        model: result.model || model.id,
        status: :succeeded,
        tokens: result.tokens,
        cost: @provider.batch_cost(result.tokens, model:, category:),
        message: result.is_a?(Message) ? result : nil
      )
      result.ruby_llm_usage_entries = [entry]
      Usage.instrument(entry, config: @provider.config) if instrument
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
        status.to_s.match?(/cancel/i) ? :cancelled : :failed
      end

      def batch_error_message(line)
        response = line['response']
        body = response['body'] if response.is_a?(Hash)
        body_error = body['error'] if body.is_a?(Hash)
        response_error = response['error'] if response.is_a?(Hash)

        batch_error_value(line['error']) ||
          line['error_message'] ||
          batch_error_value(body_error) ||
          batch_error_value(response_error)
      end

      def batch_error_value(error)
        case error
        when Hash then error['message']
        when String then error
        end
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

    def inspect_attributes # :nodoc:
      { id: id, status: status, raw_status: raw_status, chats: chats&.count, requests: requests&.count }
    end
  end
end
