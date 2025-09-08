# frozen_string_literal: true

module RubyLLM
  module Providers
    class RedCandle
      module Chat
        # Override the base complete method to handle local execution
        def complete(messages, tools:, temperature:, model:, params: {}, headers: {}, schema: nil, &)
          payload = render_payload(
            messages,
            tools: tools,
            temperature: temperature,
            model: model,
            stream: block_given?,
            schema: schema
          ).merge(params)

          if block_given?
            perform_streaming_completion!(payload, &)
          else
            result = perform_completion!(payload)
            # Convert to Message object for compatibility
            Message.new(
              role: result[:role].to_sym,
              content: result[:content],
              model_id: model.id
            )
          end
        end

        def render_payload(messages, tools:, temperature:, model:, stream:, schema:)
          # Red Candle doesn't support tools
          if tools && !tools.empty?
            raise Error.new(nil, 'Red Candle provider does not support tool calling')
          end

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
                     messages.map { |m| "#{m[:role]}: #{m[:content]}" }.join("\n\n") + "\n\nassistant:"
                   end

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
                     messages.map { |m| "#{m[:role]}: #{m[:content]}" }.join("\n\n") + "\n\nassistant:"
                   end

          # Configure generation
          config = ::Candle::GenerationConfig.balanced(
            temperature: payload[:temperature] || 0.7,
            max_length: payload[:max_tokens] || 512
          )

          # Stream tokens
          model.generate_stream(prompt, config: config) do |token|
            chunk = format_stream_chunk(token)
            block.call(chunk)
          end

          # Send final chunk with empty content (indicates completion)
          final_chunk = format_stream_chunk('')
          block.call(final_chunk)
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
          
          if gguf_file
            # For GGUF models, use the tokenizer if specified, otherwise use model_id
            options = { device: @device, gguf_file: gguf_file }
            options[:tokenizer] = tokenizer if tokenizer
            
            ::Candle::LLM.from_pretrained(model_id, **options)
          else
            # For regular models, use from_pretrained without gguf_file
            ::Candle::LLM.from_pretrained(model_id, device: @device)
          end
        rescue StandardError => e
          raise Error.new(nil, "Failed to load model #{model_id}: #{e.message}")
        end

        def format_messages(messages)
          messages.map do |msg|
            {
              role: msg[:role].to_s,
              content: extract_message_content(msg)
            }
          end
        end

        def extract_message_content(message)
          content = message[:content]
          return content if content.is_a?(String)

          # Handle array content (e.g., with images)
          if content.is_a?(Array)
            content.map do |part|
              part[:text] if part[:type] == 'text'
            end.compact.join(' ')
          else
            content.to_s
          end
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
      end
    end
  end
end