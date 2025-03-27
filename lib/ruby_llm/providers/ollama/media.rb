# frozen_string_literal: true

module RubyLLM
  module Providers
    module Ollama
      # Handles formatting of text or media content for Ollama
      module Media
        module_function

        def format_messages(messages)
          messages.map do |msg|
            text = nil
            images = []

            if msg.content.is_a?(Array)
              msg.content.each do |part|
                case part[:type]
                when 'text'
                  text = part[:text]
                when 'image'
                  images << part[:source][:data]
                end
              end
            else
              text = msg.content
            end

            {
              role: msg.role.to_s,
              content: text
            }.tap { |h| h.merge!(images: images) if images.any? }
          end
        end
      end
    end
  end
end
