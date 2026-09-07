# frozen_string_literal: true

module RubyLLM
  # A hosted, single-turn research task. RubyLLM.research_later returns a
  # job immediately; #wait polls it and #message returns its report.
  # The provider's agent identity is separate from an inference model.
  #
  #   job = RubyLLM.research_later(question, provider: provider, agent: agent_id)
  #   job.wait
  #   puts job.message.content
  #
  class ResearchJob
    include Support::Inspectable

    class DeadlineExpired < StandardError; end
    private_constant :DeadlineExpired

    # A research failure that retains the job for inspection or recovery.
    class Error < RubyLLM::Error
      # The research job, including its remote ID and last known state.
      attr_reader :job

      # Creates an error retaining +job+ and the optional HTTP response.
      def initialize(message, job:, response: nil)
        @job = job
        super(message, response:)
      end
    end

    # Raised when polling exceeds its deadline. The independent job may
    # still be running; Error#job retains its ID.
    class TimeoutError < Error; end

    # An interrupted blocking research call retaining its remote job.
    class InterruptedError < Interrupt
      # The job whose cancellation was attempted before interrupting.
      attr_reader :job

      # Creates an interruption retaining +job+ for recovery.
      def initialize(message, job:)
        @job = job
        super(message)
      end
    end

    # The provider-assigned job ID.
    attr_reader :id

    # The provider slug.
    attr_reader :provider

    # The hosted agent's identity, separate from a model ID.
    attr_reader :agent

    # The normalized state: +:pending+, +:completed+, +:incomplete+,
    # +:failed+, or +:cancelled+.
    attr_reader :status

    # The provider's failure explanation, if any.
    attr_reader :error

    # The original provider response from submission or the latest poll.
    attr_reader :raw

    # The error from an unsuccessful automatic cancellation attempt, if any.
    attr_reader :cancellation_error

    # Submits one research task without waiting. +provider:+ and +agent:+
    # are required; +with:+ attaches documents or images where supported.
    # +server_tools:+ accepts an array of aliases or a Hash of aliases
    # and their options, as on Chat#with_server_tools.
    def self.research_later(prompt, provider:, agent:, with: nil, server_tools: nil,
                            context: nil, provider_options: {}, metadata: nil)
      config = context&.config || RubyLLM.config
      instance = Provider.resolve!(provider).new(config)
      payload = { provider: instance.slug, agent:, prompt:, metadata: }
      RubyLLM.instrument('research_job.ruby_llm', payload, config:) do |event|
        job = instance.research_later(prompt, agent:, with:, server_tools:, provider_options:)
        event[:job_id] = job.id
        event[:status] = job.status
        job
      end
    end

    # Runs a research task and returns its Message. On a timeout or
    # interrupt, attempts to cancel the remote task before raising an
    # error retaining the job. +timeout:+ and +interval:+ are seconds.
    def self.research(prompt, timeout: 600, interval: 5, **options)
      validate_polling_options(timeout, interval)
      job = research_later(prompt, **options)
      job.wait(timeout:, interval:).message
    rescue Interrupt => e
      raise unless job

      job.send(:attempt_cancellation)
      raise InterruptedError.new("Research interrupted (job #{job.id})", job:), cause: e
    rescue StandardError => e
      job ||= e.job if e.is_a?(Error)
      raise unless job

      job.send(:attempt_cancellation)
      raise if e.is_a?(Error)

      response = e.response if e.respond_to?(:response)
      raise Error.new("Research failed: #{e.message} (job #{job.id})", job:, response:), cause: e
    end

    # Retrieves an existing task by ID without submitting another one.
    # Use the same provider configuration that created the task.
    def self.find(id, provider:, context: nil)
      config = context&.config || RubyLLM.config
      Provider.resolve!(provider).new(config).find_research_job(id)
    end

    def self.validate_polling_options(timeout, interval) # :nodoc:
      return if [timeout, interval].all? { |value| value.is_a?(Numeric) && value.positive? && value.finite? }

      raise ArgumentError, 'Research timeout and interval must be positive finite numbers'
    end

    def initialize(id:, provider:, agent:, protocol:, **state) # :nodoc:
      @id = id
      @provider = provider.to_sym
      @agent = agent
      @protocol = protocol
      apply_state(state)
    end

    # Returns whether the task is waiting or running.
    def pending? = status == :pending

    # Returns whether the task reached any terminal state.
    def done? = !pending?

    # Returns whether the task finished with a complete report.
    def completed? = status == :completed

    # Returns whether the provider stopped before completing the report.
    def incomplete? = status == :incomplete

    # Returns whether the provider reported failure.
    def failed? = status == :failed

    # Returns whether the provider confirmed cancellation.
    def cancelled? = status == :cancelled

    # Fetches the latest state and returns self. Does nothing after the
    # task finishes. +timeout:+ limits this request in seconds.
    def refresh(timeout: nil)
      self.class.validate_polling_options(timeout, 1) unless timeout.nil?
      unless done?
        state = request_with_timeout(timeout) { @protocol.refresh_research_job(self, timeout:) }
        apply_state(state)
      end
      self
    end

    # Polls until a terminal state and returns self. A timeout leaves the
    # independent task running and raises TimeoutError with this job.
    # Incomplete reports remain available through #message.
    def wait(timeout: 600, interval: 5)
      self.class.validate_polling_options(timeout, interval)
      deadline = monotonic_time + timeout
      until done?
        remaining = deadline - monotonic_time
        raise TimeoutError.new("Research timed out (job #{id})", job: self) unless remaining.positive?

        refresh(timeout: remaining)
        sleep [interval, deadline - monotonic_time].min if pending? && monotonic_time < deadline
      end
      raise Error.new("Research #{status}: #{error} (job #{id})", job: self) if failed? || cancelled?

      self
    end

    # Requests cancellation and returns self. Only the provider's response
    # can confirm cancellation; this does not delete stored task data.
    def cancel(timeout: 5)
      self.class.validate_polling_options(timeout, 1)
      unless done?
        state = request_with_timeout(timeout) { @protocol.cancel_research_job(self, timeout:) }
        apply_state(state)
      end
      self
    end

    # Returns the report, or +nil+ while pending. An incomplete report has
    # Message#finish_reason +:max_tokens+. Raises Error for failed or
    # cancelled tasks.
    def message
      raise Error.new("Research #{status}: #{error} (job #{id})", job: self) if failed? || cancelled?

      @message
    end

    # Returns the provider-reported task usage. Unreported fields are nil.
    attr_reader :tokens

    # Returns the reported cost, or unknown cost when the provider supplies
    # no price. Agent IDs are never used to look up model token prices.
    def cost
      Cost.from_h({ total: tokens.reported_cost }.compact, tokens:)
    end

    private

    def request_with_timeout(timeout, &)
      Timeout.timeout(timeout, DeadlineExpired, &)
    rescue DeadlineExpired, Faraday::TimeoutError => e
      raise TimeoutError.new("Research request timed out (job #{id})", job: self), cause: e
    rescue Error
      raise
    rescue RubyLLM::Error, Faraday::Error => e
      response = e.response if e.respond_to?(:response)
      @raw = response.body if response.respond_to?(:body)
      raise Error.new("Research request failed: #{e.message} (job #{id})", job: self, response:), cause: e
    end

    def apply_state(state)
      @status = state.fetch(:status)
      @raw = state[:raw]
      @error = state[:error]
      @message = state[:message]
      @tokens = state[:tokens] || @message&.tokens || Tokens.new
    end

    def attempt_cancellation
      cancel(timeout: 5)
    rescue StandardError => e
      @cancellation_error = e
    end

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def inspect_attributes # :nodoc:
      { id:, provider:, agent:, status: }
    end
  end
end
