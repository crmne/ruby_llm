# frozen_string_literal: true

require 'faraday'

module RubyLLM
  # Internal accounting for physical provider attempts.
  class Usage # :nodoc:
    def self.instrument(entry, config:) # :nodoc:
      RubyLLM.instrument(
        'usage.ruby_llm',
        {
          operation: entry.operation,
          provider: entry.provider,
          model: entry.model,
          status: entry.status,
          tokens: entry.tokens,
          cost: entry.cost
        },
        config:
      )
    end

    # Shared storage for result objects carrying attempt accounting.
    module Result
      def ruby_llm_usage_entries # :nodoc:
        @ruby_llm_usage_entries ||= []
      end

      def ruby_llm_usage_entries=(entries) # :nodoc:
        @ruby_llm_usage_entries = Array(entries)
        @ruby_llm_usage_entries.each { |entry| entry.message = self if is_a?(Message) }
      end

      private

      def ruby_llm_usage_tokens
        Tokens.aggregate(ruby_llm_usage_entries.map(&:tokens))
      end

      def ruby_llm_usage_cost
        Cost.aggregate(
          ruby_llm_usage_entries.map(&:cost),
          complete: ruby_llm_usage_entries.all?(&:usage_available?)
        )
      end
    end

    # One physical provider request attempt and its accounting facts.
    class Entry
      OPERATIONS = %i[chat embedding moderation image speech transcription].freeze
      STATUSES = %i[pending succeeded failed cancelled].freeze

      attr_reader :operation, :provider, :model, :status, :tokens, :cost
      attr_accessor :message

      def initialize(operation:, provider:, model:, status: :pending, tokens: nil, cost: nil, message: nil) # rubocop:disable Metrics/ParameterLists
        @operation = operation.to_sym
        @provider = provider.to_s
        @model = model.to_s
        @status = status.to_sym
        @tokens = tokens || Tokens.new
        @cost = cost || Cost.new(tokens: @tokens)
        @message = message
        validate!
      end

      def pending? = status == :pending
      def succeeded? = status == :succeeded
      def failed? = status == :failed
      def cancelled? = status == :cancelled
      def usage_available? = tokens.to_h.any?

      def to_h
        {
          operation: operation,
          provider: provider,
          model: model,
          status: status,
          tokens: tokens.to_h,
          cost: cost.to_h
        }
      end

      def finish(status:, tokens: nil, cost: nil) # :nodoc:
        @status = status.to_sym
        @tokens = tokens || Tokens.new
        @cost = cost || Cost.new(tokens: @tokens)
        validate!
        self
      end

      private

      def validate!
        raise ArgumentError, "Unknown usage operation: #{operation.inspect}" unless OPERATIONS.include?(operation)
        raise ArgumentError, "Unknown usage status: #{status.inspect}" unless STATUSES.include?(status)
      end
    end

    # Tracks the physical transport attempts belonging to one operation.
    class Tracker # :nodoc:
      CATEGORY_BY_OPERATION = {
        chat: :text_tokens,
        embedding: :embeddings,
        moderation: :text_tokens,
        image: :images,
        speech: :audio_tokens,
        transcription: :audio_tokens
      }.freeze

      attr_reader :entries

      def initialize(operation:, provider:, model:, config:, on_finish: nil)
        @operation = operation.to_sym
        @provider = provider
        @model_info = model
        @config = config
        @on_finish = on_finish
        @entries = []
        @pending = []
      end

      def start
        entry = Entry.new(operation: @operation, provider: @provider.slug, model: @model_info.id)
        @entries << entry
        @pending << entry
        entry
      end

      def observe(chunk)
        entry = @pending.last
        return unless entry
        return unless chunk.respond_to?(:tokens)

        entry.finish(
          status: :pending,
          tokens: merge_stream_tokens(entry.tokens, chunk.tokens)
        )
      end

      def fail_attempt(entry, error)
        return unless entry&.pending?

        status = error.is_a?(CancelledError) ? :cancelled : :failed
        finish(entry, status:, tokens: failure_tokens(entry, error))
      end

      def fail_pending(error)
        @pending.dup.each { |entry| fail_attempt(entry, error) }
      end

      def succeed(result)
        pending = @pending.dup
        if pending.empty?
          attach_to_result(result)
          return result
        end

        tokens = result.respond_to?(:tokens) ? result.tokens : Tokens.new
        cost = result.cost if result.respond_to?(:cost)
        pending[0...-1].each do |entry|
          finish(entry, status: :succeeded, tokens: Tokens.new)
        end
        finish(pending.last, status: :succeeded, tokens:, cost:)
        attach_to_result(result)
        result
      end

      def succeed_attempts(tokens:)
        @pending.dup.zip(tokens).each do |entry, usage|
          finish(entry, status: :succeeded, tokens: usage)
        end
      end

      private

      # A request that never reached the provider cannot have been billed;
      # possibly-billed failures keep their usage unknown.
      def failure_tokens(entry, error)
        return entry.tokens if entry.usage_available? || !never_sent?(error)

        Tokens.new(input: 0, output: 0)
      end

      def never_sent?(error)
        error.is_a?(Faraday::ConnectionFailed) || error.is_a?(Faraday::SSLError)
      end

      def finish(entry, status:, tokens:, **details)
        cost = details[:cost] || Cost.new(
          tokens:,
          model: @model_info,
          category: CATEGORY_BY_OPERATION.fetch(@operation)
        )
        entry.finish(status:, tokens:, cost:)
        @pending.delete(entry)
        instrument(entry)
        @on_finish&.call(entry)
      end

      def instrument(entry)
        Usage.instrument(entry, config: @config)
      end

      def attach_to_result(result)
        result.ruby_llm_usage_entries = entries
      end

      def merge_stream_tokens(existing, incoming)
        Tokens.new(
          input: incoming.input.nil? ? existing.input : incoming.input,
          output: incoming.output.nil? ? existing.output : incoming.output,
          cache_read: incoming.cache_read.nil? ? existing.cache_read : incoming.cache_read,
          cache_write: incoming.cache_write.nil? ? existing.cache_write : incoming.cache_write,
          thinking: incoming.thinking.nil? ? existing.thinking : incoming.thinking
        )
      end
    end
  end
end
