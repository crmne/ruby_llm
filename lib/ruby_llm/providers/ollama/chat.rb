# frozen_string_literal: true

module RubyLLM
  module Providers
    module Ollama
      # Chat methods for the Ollama API implementation
      module Chat # rubocop:disable Metrics/ModuleLength
        # Must be public for Provider to use
        def complete(messages, tools:, temperature:, model:, &block) # rubocop:disable Metrics/MethodLength
          raise NotImplementedError.new('tool use not implemented in Ollama at this time') if tools.any?

          payload = {
            model: model,
            messages: format_messages(messages),
            options: {
              temperature: temperature
            }
          }

          if block_given?
            payload[:stream] = true
            stream_completion(model, payload, &block)
          else
            payload[:stream] = false
            generate_completion(model, payload)
          end
        end

        # Format methods can be private
        private

        def generate_completion(_model, payload)
          url = 'api/chat'
          response = post(url, payload)
          parse_completion_response(response)
        end

        def format_messages(messages)
          messages.map do |msg|
            {
              role: format_role(msg.role),
              content: format_parts(msg)
            }
          end
        end

        def format_role(role)
          case role
          when :assistant
          when :system
          when :tool
            role.to_s
          # FIXME: probably should validate this
          else role.to_s
          end
        end

        def format_parts(msg) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          if msg.content.is_a?(Array)
            # Handle multi-part content (text, images, etc.)
            msg.content.map { |part| format_part(part) }
          else
            # Simple text content
            msg.content.to_s
          end
        end

        def format_part(part) # rubocop:disable Metrics/MethodLength
          case part[:type]
          when 'text'
            { text: part[:text] }
          when 'image'
            Media.format_image(part)
          when 'pdf'
            Media.format_pdf(part)
          when 'audio'
            Media.format_audio(part)
          else
            { text: part.to_s }
          end
        end

        def parse_completion_response(response)
          data = response.body

          Message.new(
            role: :assistant,
            content: data.dig('message', 'content'),
            input_tokens: data['prompt_eval_count'].to_i,
            output_tokens: data['eval_count'].to_i,
            model_id: data['model']
          )
        end
      end
    end
  end
end
