# frozen_string_literal: true

require 'json'
require 'shellwords'
require 'tempfile'
require 'fileutils'

module RubyLLM
  module AgentSDK
    module Testing
      # MockCLI simulates the Claude CLI subprocess for testing
      # without making actual API calls
      class MockCLI
        attr_reader :messages, :args_received

        def initialize(messages = [])
          @messages = messages
          @args_received = nil
          @script_file = nil
          @json_file = nil
        end

        # Create a mock CLI script that outputs predefined messages
        def create_script
          # Write JSON messages to a separate file to avoid escaping issues
          @json_file = Tempfile.new(['mock_messages', '.json'])
          @messages.each { |m| @json_file.puts(m.to_json) }
          @json_file.close

          @script_file = Tempfile.new(['mock_claude', '.sh'])
          @script_file.write(script_content(@json_file.path))
          @script_file.close
          File.chmod(0o755, @script_file.path)

          # Return path to use as cli_path
          @script_file.path
        end

        def cleanup
          @script_file&.unlink
          @json_file&.unlink
        end

        private

        def script_content(json_path)
          <<~BASH
            #!/bin/bash
            # Mock Claude CLI for testing
            cat #{Shellwords.shellescape(json_path)}
          BASH
        end

        class << self
          # Create a simple query response
          def simple_response(text, session_id: 'test-session-123')
            new([
              init_message(session_id: session_id),
              assistant_message(text),
              result_message(session_id: session_id)
            ])
          end

          # Create a response with tool usage
          def with_tool_use(text, tool_name:, tool_input:, tool_result:, session_id: 'test-session-123')
            new([
              init_message(session_id: session_id),
              tool_use_message(tool_name, tool_input),
              tool_result_message(tool_name, tool_result),
              assistant_message(text),
              result_message(session_id: session_id)
            ])
          end

          # Create an error response
          def error_response(error_type, session_id: 'test-session-123')
            new([
              init_message(session_id: session_id),
              result_message(session_id: session_id, subtype: error_type)
            ])
          end

          # Message factory methods
          def init_message(session_id:)
            {
              type: 'system',
              subtype: 'init',
              session_id: session_id,
              cwd: Dir.pwd,
              model: 'claude-sonnet-4-20250514',
              tools: %w[Bash Read Write Edit Glob Grep],
              permissionMode: 'default'
            }
          end

          def assistant_message(text)
            {
              type: 'assistant',
              message: {
                role: 'assistant',
                content: [{ type: 'text', text: text }]
              }
            }
          end

          def tool_use_message(tool_name, input)
            {
              type: 'assistant',
              message: {
                role: 'assistant',
                content: [
                  {
                    type: 'tool_use',
                    id: "tool_#{SecureRandom.hex(8)}",
                    name: tool_name,
                    input: input
                  }
                ]
              }
            }
          end

          def tool_result_message(_tool_name, result)
            {
              type: 'user',
              message: {
                role: 'user',
                content: [
                  {
                    type: 'tool_result',
                    tool_use_id: "tool_#{SecureRandom.hex(8)}",
                    content: result
                  }
                ]
              }
            }
          end

          def result_message(session_id:, subtype: 'success')
            {
              type: 'result',
              subtype: subtype,
              session_id: session_id,
              duration_ms: 1500,
              duration_api_ms: 1200,
              num_turns: 1,
              total_cost_usd: 0.005,
              usage: {
                input_tokens: 100,
                output_tokens: 50
              }
            }
          end
        end
      end

      # Cassette-style recording/playback for CLI interactions
      # Similar to VCR for HTTP, but for CLI subprocess interactions
      #
      # @example Recording a cassette
      #   cassette = CLICassette.new('simple_query')
      #   cassette.use_cassette(record: :new_episodes) do |cli_path|
      #     RubyLLM::AgentSDK.query("Hello", cli_path: cli_path) { |msg| }
      #   end
      #
      # @example Playing back a cassette
      #   cassette = CLICassette.new('simple_query')
      #   cassette.use_cassette do |cli_path|
      #     RubyLLM::AgentSDK.query("Hello", cli_path: cli_path) { |msg| }
      #   end
      #
      class CLICassette
        CASSETTE_DIR = 'spec/fixtures/cli_cassettes'

        # Record modes (similar to VCR):
        # - :none - Only playback, error if cassette doesn't exist
        # - :new_episodes - Record if cassette doesn't exist, playback if it does
        # - :all - Always record, overwrite existing cassette
        RECORD_MODES = %i[none new_episodes all].freeze

        attr_reader :name, :messages, :metadata

        def initialize(name)
          @name = name
          @messages = []
          @metadata = {}
          @recording = false
          @mock_cli = nil
        end

        # Use this cassette for a test block
        #
        # @param record [Symbol] Record mode (:none, :new_episodes, :all)
        # @yield [String] The CLI path to use (mock or real)
        def use_cassette(record: :none)
          should_record = case record
                          when :all then true
                          when :new_episodes then !cassette_exists?
                          when :none then false
                          else raise ArgumentError, "Unknown record mode: #{record}"
                          end

          if should_record
            yield_with_recording { |cli_path| yield cli_path }
          else
            yield_with_playback { |cli_path| yield cli_path }
          end
        end

        # Check if cassette file exists
        def cassette_exists?
          File.exist?(cassette_path)
        end

        # Start recording mode
        def record!
          @recording = true
          @messages = []
          @metadata = {
            recorded_at: Time.now.iso8601,
            ruby_llm_version: RubyLLM::AgentSDK::VERSION
          }
        end

        def recording?
          @recording
        end

        # Add a message during recording
        def add_message(message)
          return unless @recording

          @messages << message
        end

        # Save cassette to disk
        def save
          FileUtils.mkdir_p(CASSETTE_DIR)
          cassette_data = {
            metadata: @metadata,
            messages: @messages
          }
          File.write(cassette_path, JSON.pretty_generate(cassette_data))
        end

        # Load cassette from disk
        def load
          return false unless cassette_exists?

          data = JSON.parse(File.read(cassette_path), symbolize_names: true)
          @metadata = data[:metadata] || {}
          @messages = data[:messages] || []
          true
        end

        def cassette_path
          File.join(CASSETTE_DIR, "#{@name}.json")
        end

        # Convert loaded cassette to MockCLI for playback
        def to_mock_cli
          MockCLI.new(@messages)
        end

        private

        # Record real CLI interaction
        def yield_with_recording
          record!
          @metadata[:prompt] = nil

          # Use a wrapper CLI that records messages
          recorder = RecordingCLI.new(self)
          yield recorder.cli_path

          save
        ensure
          recorder&.cleanup
        end

        # Playback from cassette
        def yield_with_playback
          unless load
            raise CassetteNotFoundError, "Cassette '#{@name}' not found at #{cassette_path}. " \
                                         'Record it first with record: :new_episodes'
          end

          @mock_cli = to_mock_cli
          yield @mock_cli.create_script
        ensure
          @mock_cli&.cleanup
        end
      end

      # Error raised when cassette is not found during playback
      class CassetteNotFoundError < StandardError; end

      # Wrapper that records real CLI interactions
      class RecordingCLI
        attr_reader :cassette

        def initialize(cassette)
          @cassette = cassette
          @real_cli_path = find_real_cli
          @script_file = nil
          @output_file = nil
        end

        # Create a wrapper script that runs the real CLI and captures output
        def cli_path
          @output_file = Tempfile.new(['cli_output', '.jsonl'])
          @output_file.close

          @script_file = Tempfile.new(['recording_cli', '.sh'])
          @script_file.write(wrapper_script)
          @script_file.close
          File.chmod(0o755, @script_file.path)

          @script_file.path
        end

        def cleanup
          # Parse and save recorded messages
          if @output_file && File.exist?(@output_file.path)
            File.readlines(@output_file.path).each do |line|
              next if line.strip.empty?

              begin
                message = JSON.parse(line, symbolize_names: true)
                @cassette.add_message(message)
              rescue JSON::ParserError
                # Skip non-JSON lines
              end
            end
          end

          @script_file&.unlink
          @output_file&.unlink
        end

        private

        def find_real_cli
          # Check common locations for claude CLI
          paths = [
            `which claude 2>/dev/null`.strip,
            '/usr/local/bin/claude',
            "#{ENV['HOME']}/.local/bin/claude",
            "#{ENV['HOME']}/.claude/bin/claude"
          ]

          paths.find { |p| !p.empty? && File.executable?(p) } || 'claude'
        end

        def wrapper_script
          <<~BASH
            #!/bin/bash
            # Recording wrapper for Claude CLI
            # Captures all output while passing through to caller

            #{Shellwords.shellescape(@real_cli_path)} "$@" | tee #{Shellwords.shellescape(@output_file.path)}
          BASH
        end
      end

      # RSpec helper methods for cassette testing
      module RSpecHelpers
        # Use a cassette in a test
        #
        # @param name [String] Cassette name
        # @param record [Symbol] Record mode
        # @yield [String] The CLI path to use
        #
        # @example
        #   it 'does something' do
        #     use_cli_cassette('my_test', record: :new_episodes) do |cli_path|
        #       messages = []
        #       RubyLLM::AgentSDK.query("Hello", cli_path: cli_path) { |m| messages << m }
        #       expect(messages).not_to be_empty
        #     end
        #   end
        def use_cli_cassette(name, record: :none, &block)
          cassette = CLICassette.new(name)
          cassette.use_cassette(record: record, &block)
        end

        # Create a mock CLI for inline test data
        #
        # @param messages [Array<Hash>] Messages to return
        # @yield [String] The mock CLI path
        def with_mock_cli(messages)
          mock = MockCLI.new(messages)
          cli_path = mock.create_script
          yield cli_path
        ensure
          mock&.cleanup
        end

        # Create a simple response mock
        #
        # @param text [String] Response text
        # @yield [String] The mock CLI path
        def with_simple_response(text)
          mock = MockCLI.simple_response(text)
          cli_path = mock.create_script
          yield cli_path
        ensure
          mock&.cleanup
        end
      end
    end
  end
end

# RSpec configuration for cli_cassette support
if defined?(RSpec)
  RSpec.configure do |config|
    config.include RubyLLM::AgentSDK::Testing::RSpecHelpers, type: :integration
    config.include RubyLLM::AgentSDK::Testing::RSpecHelpers, integration: true
  end
end
