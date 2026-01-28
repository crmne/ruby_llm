# frozen_string_literal: true

module RubyLLM
  module Providers
    class VertexAI
      # Embeddings methods for the Vertex AI implementation
      module Embeddings
        module_function

        def embedding_url(model:)
          "projects/#{@config.vertexai_project_id}/locations/#{@config.vertexai_location}/publishers/google/models/#{model}:predict" # rubocop:disable Layout/LineLength
        end

        def render_embedding_payload(text, model:, dimensions: nil, with: nil) # rubocop:disable Lint/UnusedMethodArgument
          is_multimodal = with.present?

          if is_multimodal
            render_multimodal_payload(text:, with:, dimensions:)
          else
            {
              instances: [text].flatten.map { |t| { text: t.to_s } }
            }.tap do |payload|
              payload[:parameters] = { dimension: dimensions } if dimensions
            end
          end
        end

        def render_multimodal_payload(text:, with:, dimensions:)
          files = categorize_files(with)

          validate_multimodal_inputs(files)

          instance = {}
          instance[:text] = text.to_s if text
          add_image_instance(instance, image: files[:image].first) if files[:image].any?
          add_video_instance(instance, video: files[:video].first) if files[:video].any?

          {
            instances: [instance]
          }.tap do |payload|
            payload[:parameters] = { dimension: dimensions } if dimensions
          end
        end

        def validate_multimodal_inputs(files)
          raise ArgumentError, 'This model only supports one image at a time.' if files[:image].size > 1
          raise ArgumentError, 'This model only supports one video at a time.' if files[:video].size > 1
        end

        def categorize_files(files)
          result = { image: [], video: [] }

          Array(files).each do |file|
            case detect_file_type(file)
            when :image
              result[:image] << file
            when :video
              result[:video] << file
            else
              raise ArgumentError, "Unsupported file type for file: #{file}"
            end
          end
          result
        end

        def detect_file_type(file)
          filename = if file.respond_to?(:path)
                       file.path
                     elsif file.is_a?(String)
                       file
                     else
                       return :unknown
                     end
          extension = File.extname(filename).downcase

          return :image if %w[.jpg .jpeg .png .gif .bmp].include?(extension)
          return :video if %w[.avi .flv .mkv .mov .mp4 .mpeg .mpg .webm .wmv].include?(extension)

          :unknown
        end

        def add_image_instance(instance, image:)
          return unless image.present?

          require 'base64'
          image_data = image.respond_to?(:read) ? image.read : image
          instance[:image] = { bytesBase64Encoded: Base64.strict_encode64(image_data) }
        end

        def add_video_instance(instance, video:)
          return unless video.present?

          require 'base64'
          if video.is_a?(String) && video.start_with?('gs://')
            instance[:video] = { gcsUri: video }
          else
            video_data = video.respond_to?(:read) ? video.read : video
            instance[:video] = { bytesBase64Encoded: Base64.strict_encode64(video_data) }
          end
        end

        def parse_embedding_response(response, model:, text:)
          predictions = response.body['predictions']

          if model == 'multimodalembedding'
            vectors = parse_multimodal_embeddings(predictions)
          else
            vectors = predictions&.map { |p| p.dig('embeddings', 'values') }
            vectors = vectors.first if vectors&.length == 1 && !text.is_a?(Array)
          end
          Embedding.new(vectors:, model:, input_tokens: 0)
        end

        def parse_multimodal_embeddings(predictions)
          text_embedding = predictions&.dig(0, 'textEmbedding')
          image_embedding = predictions&.dig(0, 'imageEmbedding')
          video_embedding = predictions&.dig(0, 'videoEmbedding')

          vectors = {}
          vectors[:text] = text_embedding if text_embedding
          vectors[:image] = image_embedding if image_embedding
          vectors[:video] = video_embedding if video_embedding
          vectors
        end
      end
    end
  end
end
