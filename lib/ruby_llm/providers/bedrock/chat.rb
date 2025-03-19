# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # Chat implementation for AWS Bedrock
      class Chat
        def initialize(model:, temperature: nil, max_tokens: nil)
          @model = model
          @temperature = temperature
          @max_tokens = max_tokens
        end

        def chat(messages:, stream: false)
          request_body = build_request_body(messages)
          path = "/model/#{model_id}/invoke#{stream ? '-with-response-stream' : ''}"
          
          if stream
            stream_response(path, request_body)
          else
            complete_response(path, request_body)
          end
        end

        private

        attr_reader :model, :temperature, :max_tokens

        def connection
          Bedrock.config.connection
        end

        def build_request_body(messages)
          # Format depends on the specific model being used
          case model_id
          when /anthropic\.claude/
            build_claude_request(messages)
          when /amazon\.titan/
            build_titan_request(messages)
          else
            raise Error, "Unsupported model: #{model_id}"
          end
        end

        def build_claude_request(messages)
          formatted = messages.map do |msg|
            role = msg[:role] == 'assistant' ? 'Assistant' : 'Human'
            content = msg[:content]
            "\n\n#{role}: #{content}"
          end.join

          {
            prompt: formatted + "\n\nAssistant:",
            temperature: temperature,
            max_tokens: max_tokens
          }
        end

        def build_titan_request(messages)
          {
            inputText: messages.map { |msg| msg[:content] }.join("\n"),
            textGenerationConfig: {
              temperature: temperature,
              maxTokenCount: max_tokens
            }
          }
        end

        def model_id
          case model
          when 'claude-3-sonnet'
            'anthropic.claude-3-sonnet-20240229-v1:0'
          when 'claude-2'
            'anthropic.claude-v2'
          when 'claude-instant'
            'anthropic.claude-instant-v1'
          when 'titan'
            'amazon.titan-text-express-v1'
          else
            model # assume it's a full model ID
          end
        end

        def complete_response(path, body)
          response = make_request(:post, path, body)
          parse_response(response.body)
        end

        def stream_response(path, body)
          Enumerator.new do |yielder|
            response = make_request(:post, path, body)
            parser = EventStreamParser.new

            response.body.each do |chunk|
              parser.feed(chunk) do |event|
                parsed_chunk = parse_stream_event(event)
                yielder << parsed_chunk if parsed_chunk
              end
            end
          end
        end

        def make_request(method, path, body)
          json_body = JSON.generate(body)
          headers = SignatureV4.sign_request(
            connection: connection,
            method: method,
            path: path,
            body: json_body,
            access_key: Bedrock.config.access_key_id,
            secret_key: Bedrock.config.secret_access_key,
            session_token: Bedrock.config.session_token,
            region: Bedrock.config.region
          )

          headers['Content-Type'] = 'application/json'
          headers['Accept'] = 'application/json'

          response = connection.public_send(method, path) do |req|
            req.headers.merge!(headers)
            req.body = json_body
          end

          raise Error, "Request failed: #{response.body}" unless response.success?

          response
        end

        def parse_response(body)
          case model_id
          when /anthropic\.claude/
            parse_claude_response(body)
          when /amazon\.titan/
            parse_titan_response(body)
          else
            raise Error, "Unsupported model: #{model_id}"
          end
        end

        def parse_stream_event(event)
          return unless event.data

          body = JSON.parse(event.data, symbolize_names: true)
          
          case model_id
          when /anthropic\.claude/
            parse_claude_stream_chunk(body)
          when /amazon\.titan/
            parse_titan_stream_chunk(body)
          else
            raise Error, "Unsupported model: #{model_id}"
          end
        end

        def parse_claude_response(body)
          {
            role: 'assistant',
            content: body[:completion]
          }
        end

        def parse_titan_response(body)
          {
            role: 'assistant',
            content: body[:results].first[:outputText]
          }
        end

        def parse_claude_stream_chunk(body)
          return unless body[:completion]

          {
            role: 'assistant',
            content: body[:completion],
            delta: true
          }
        end

        def parse_titan_stream_chunk(body)
          text = body[:outputText]
          return unless text

          {
            role: 'assistant',
            content: text,
            delta: true
          }
        end
      end
    end
  end
end 