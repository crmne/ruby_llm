# frozen_string_literal: true

module RubyLLM
  module Providers
    class RedCandle
      # Chat implementation for Red Candle provider
      module Chat
        # Override the base complete method to handle local execution
        def complete(messages, tools:, temperature:, model:, params: {}, headers: {}, schema: nil, &) # rubocop:disable Metrics/ParameterLists
          _ = headers # Interface compatibility
          payload = Utils.deep_merge(
            render_payload(
              messages,
              tools: tools,
              temperature: temperature,
              model: model,
              stream: block_given?,
              schema: schema
            ),
            params
          )

          if block_given?
            perform_streaming_completion!(payload, &)
          else
            result = perform_completion!(payload)
            # Convert to Message object for compatibility
            # Red Candle doesn't provide token counts, but we can estimate them
            content = result[:content]
            # Rough estimation: ~4 characters per token
            estimated_output_tokens = (content.length / 4.0).round
            estimated_input_tokens = estimate_input_tokens(payload[:messages])

            Message.new(
              role: result[:role].to_sym,
              content: content,
              model_id: model.id,
              input_tokens: estimated_input_tokens,
              output_tokens: estimated_output_tokens
            )
          end
        end

        def render_payload(messages, tools:, temperature:, model:, stream:, schema:) # rubocop:disable Metrics/ParameterLists
          # Red Candle doesn't support tools
          raise Error.new(nil, 'Red Candle provider does not support tool calling') if tools && !tools.empty?

          {
            messages: messages,
            temperature: temperature,
            model: model.id,
            stream: stream,
            schema: schema
          }
        end

        def perform_completion!(payload)
          model = ensure_model_loaded!(payload[:model])
          messages = format_messages(payload[:messages])

          # Apply chat template if available
          prompt = if model.respond_to?(:apply_chat_template)
                     model.apply_chat_template(messages)
                   else
                     # Fallback to simple formatting
                     "#{messages.map { |m| "#{m[:role]}: #{m[:content]}" }.join("\n\n")}\n\nassistant:"
                   end

          # Check context length
          validate_context_length!(prompt, payload[:model])

          # Configure generation
          config_opts = {
            temperature: payload[:temperature] || 0.7,
            max_length: payload[:max_tokens] || 512
          }

          # Handle structured generation if schema provided
          response = if payload[:schema]
                       generate_with_schema(model, prompt, payload[:schema], config_opts)
                     else
                       model.generate(
                         prompt,
                         config: ::Candle::GenerationConfig.balanced(**config_opts)
                       )
                     end

          format_response(response, payload[:schema])
        end

        def perform_streaming_completion!(payload, &block)
          model = ensure_model_loaded!(payload[:model])
          messages = format_messages(payload[:messages])

          # Apply chat template if available
          prompt = if model.respond_to?(:apply_chat_template)
                     model.apply_chat_template(messages)
                   else
                     "#{messages.map { |m| "#{m[:role]}: #{m[:content]}" }.join("\n\n")}\n\nassistant:"
                   end

          # Check context length
          validate_context_length!(prompt, payload[:model])

          # Configure generation
          config = ::Candle::GenerationConfig.balanced(
            temperature: payload[:temperature] || 0.7,
            max_length: payload[:max_tokens] || 512
          )

          # Collect all streamed content
          full_content = ''

          # Stream tokens
          model.generate_stream(prompt, config: config) do |token|
            full_content += token
            chunk = format_stream_chunk(token)
            block.call(chunk)
          end

          # Send final chunk with empty content (indicates completion)
          final_chunk = format_stream_chunk('')
          block.call(final_chunk)

          # Return a Message object with the complete response
          estimated_output_tokens = (full_content.length / 4.0).round
          estimated_input_tokens = estimate_input_tokens(payload[:messages])

          Message.new(
            role: :assistant,
            content: full_content,
            model_id: payload[:model],
            input_tokens: estimated_input_tokens,
            output_tokens: estimated_output_tokens
          )
        end

        private

        def ensure_model_loaded!(model_id)
          @loaded_models[model_id] ||= load_model(model_id)
        end

        def load_model(model_id)
          # Get GGUF file and tokenizer if this is a GGUF model
          # Access the methods from the Models module which is included in the provider
          gguf_file = respond_to?(:gguf_file_for) ? gguf_file_for(model_id) : nil
          tokenizer = respond_to?(:tokenizer_for) ? tokenizer_for(model_id) : nil

          options = { device: @device }
          options[:gguf_file] = gguf_file if gguf_file
          options[:tokenizer] = tokenizer if tokenizer
          ::Candle::LLM.from_pretrained(model_id, **options)
        rescue StandardError => e
          if e.message.include?('Failed to find tokenizer')
            raise Error.new(nil,
                            "Failed to load tokenizer '#{tokenizer}'. The tokenizer may not exist or require authentication.\n" \
                            "Please verify the tokenizer exists at: https://huggingface.co/#{tokenizer}\n" \
                            "And that you have accepted the terms of service for the tokenizer.\n" \
                            "If it requires authentication, login with: huggingface-cli login\n" \
                            "Original error: #{e.message}")
          elsif e.message.include?('Failed to find model')
            raise Error.new(nil,
                            "Failed to find model '#{model_id}'. The model may not exist or require authentication.\n" \
                            "Please verify the model exists at: https://huggingface.co/#{model_id}\n" \
                            "And that you have accepted the terms of service for the model.\n" \
                            "If it requires authentication, login with: huggingface-cli login\n" \
                            "Original error: #{e.message}")
          else
            raise Error.new(nil, "Failed to load model #{model_id}: #{e.message}")
          end
        end

        def format_messages(messages)
          messages.map do |msg|
            # Handle both hash and Message objects
            if msg.is_a?(Message)
              {
                role: msg.role.to_s,
                content: extract_message_content_from_object(msg)
              }
            else
              {
                role: msg[:role].to_s,
                content: extract_message_content(msg)
              }
            end
          end
        end

        def extract_message_content_from_object(message)
          content = message.content

          # Handle Content objects
          if content.is_a?(Content)
            # Extract text from Content object, including attachment text
            handle_content_object(content)
          elsif content.is_a?(String)
            content
          else
            content.to_s
          end
        end

        def extract_message_content(message)
          content = message[:content]

          # Handle Content objects
          case content
          when Content
            # Extract text from Content object
            handle_content_object(content)
          when String
            content
          when Array
            # Handle array content (e.g., with images)
            content.filter_map { |part| part[:text] if part[:type] == 'text' }.join(' ')
          else
            content.to_s
          end
        end

        def handle_content_object(content)
          text_parts = []
          text_parts << content.text if content.text

          # Add any text from attachments
          content.attachments&.each do |attachment|
            text_parts << attachment.data if attachment.respond_to?(:data) && attachment.data.is_a?(String)
          end

          text_parts.join(' ')
        end

        def generate_with_schema(model, prompt, schema, config_opts)
          model.generate_structured(
            prompt,
            schema: schema,
            **config_opts
          )
        rescue StandardError => e
          RubyLLM.logger.warn "Structured generation failed: #{e.message}. Falling back to regular generation."
          model.generate(
            prompt,
            config: ::Candle::GenerationConfig.balanced(**config_opts)
          )
        end

        def format_response(response, schema)
          content = if schema && !response.is_a?(String)
                      # Structured response
                      JSON.generate(response)
                    else
                      response
                    end

          {
            content: content,
            role: 'assistant'
          }
        end

        def format_stream_chunk(token)
          # Return a Chunk object for streaming compatibility
          Chunk.new(
            role: :assistant,
            content: token
          )
        end

        def estimate_input_tokens(messages)
          # Rough estimation: ~4 characters per token
          formatted = format_messages(messages)
          total_chars = formatted.sum { |msg| "#{msg[:role]}: #{msg[:content]}".length }
          (total_chars / 4.0).round
        end

        def validate_context_length!(prompt, model_id)
          # Get the context window for this model
          context_window = if respond_to?(:model_context_window)
                             model_context_window(model_id)
                           else
                             4096 # Conservative default
                           end

          # Estimate tokens in prompt (~4 characters per token)
          estimated_tokens = (prompt.length / 4.0).round

          # Check if prompt exceeds context window (leave some room for response)
          max_input_tokens = context_window - 512 # Reserve 512 tokens for response
          return unless estimated_tokens > max_input_tokens

          raise Error.new(
            nil,
            "Context length exceeded. Estimated #{estimated_tokens} tokens, " \
            "but model #{model_id} has a context window of #{context_window} tokens."
          )
        end
      end
    end
  end
end
