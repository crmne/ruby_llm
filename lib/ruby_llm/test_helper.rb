# frozen_string_literal: true

require 'ruby_llm'

module RubyLLM
  # Lets a test script what the model replies, with no provider and no API
  # key. Replies go through the real conversation loop, so streaming, tools,
  # persistence, cost, and #cancel all behave as they do in production.
  # Require it in your test helper, and include it like ActiveJob::TestHelper:
  #
  #   require "ruby_llm/test_helper"
  #
  #   class SupportAgentTest < ActiveSupport::TestCase
  #     include RubyLLM::TestHelper
  #
  #     test "answers" do
  #       stub_replies "Hello there", cost: 0.01
  #
  #       reply = SupportAgent.new.ask("Hi")
  #
  #       assert_equal "Hello there", reply.content
  #       assert_equal 0.01, reply.cost.total
  #     end
  #   end
  #
  # It also works in RSpec: <tt>config.include RubyLLM::TestHelper</tt>. A
  # chat's request reaches the stub. Other operations, such as RubyLLM.embed,
  # still call their provider.
  module TestHelper
    # The scripted replies, shared across threads because a system test's
    # server and its jobs run in threads of their own.
    module Script # :nodoc:
      @lock = Mutex.new
      @replies = nil

      class << self
        def stub(replies, options)
          @lock.synchronize { @replies = [replies, options] }
        end

        def clear
          @lock.synchronize { @replies = nil }
        end

        def active?
          @lock.synchronize { !@replies.nil? }
        end

        # The next reply. The last one repeats, so a test that doesn't count
        # requests only names one.
        def next_reply
          @lock.synchronize do
            replies, options = @replies
            [replies.size > 1 ? replies.shift : replies.first, options]
          end
        end
      end
    end

    # Answers requests from the script, once #stub_replies has been called.
    module StubbedProvider # :nodoc:
      # Skips the API key check, which some providers define for themselves.
      def initialize(config)
        if Script.active?
          @config = config
          @connection = Transport::Connection.new(self, config)
        else
          super
        end
      end

      def complete(messages, usage_recorder: nil, progress_recorder: nil, **options, &)
        return super unless Script.active?

        reply, settings = Script.next_reply
        raise reply if reply.is_a?(Exception)

        tool_call = reply if reply.is_a?(ToolCall)
        text = tool_call ? '' : reply.to_s
        stream(text, settings, options[:model], &) if block_given?
        Message.new(role: :assistant, content: text, model_id: options[:model].id,
                    tool_calls: tool_call && { tool_call.id => tool_call }, input_tokens: 1, output_tokens: 1,
                    reported_cost: settings[:cost])
      end

      private

      def stream(text, settings, model)
        text.scan(/\S+\s*|\s+/).each do |word|
          sleep settings[:interval] if settings[:interval]
          yield Chunk.new(role: :assistant, content: word, model_id: model.id)
        end
      end
    end

    Provider.prepend(StubbedProvider)

    def self.included(base) # :nodoc:
      base.after { Script.clear } if base.respond_to?(:after)
    end

    def after_teardown # :nodoc:
      Script.clear
      super
    end

    # Makes every chat answer with +replies+ until the test ends, in order,
    # repeating the last, instead of calling a provider. A String streams
    # word by word, #tool_call asks the conversation loop to run a tool, and
    # an exception such as RubyLLM::ServerError fails the request.
    # +cost:+ is what each reply reports, in dollars. +interval:+ is the
    # seconds between words, so a test can press Stop while a reply streams.
    #
    #   stub_replies "Hello there", cost: 0.01
    #   stub_replies tool_call(:weather, city: "Berlin"), "It is sunny."
    #   stub_replies "A long reply", interval: 0.1
    #
    def stub_replies(*replies, cost: nil, interval: nil)
      Script.stub(replies, { cost:, interval: })
    end

    # Returns a reply that calls the tool +name+ with +arguments+, for
    # #stub_replies.
    def tool_call(name, **arguments)
      ToolCall.new(id: "call_#{SecureRandom.hex(4)}", name: name.to_s, arguments:)
    end
  end
end
