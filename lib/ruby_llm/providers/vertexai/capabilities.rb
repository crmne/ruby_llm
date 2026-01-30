# frozen_string_literal: true

module RubyLLM
  module Providers
    class VertexAI
      # Determines capabilities for Google Vertex AI models
      module Capabilities
        module_function

        def context_window_for(model_id)
          case model_id
          when /multimodalembedding/ then 32
          end
        end

        def max_tokens_for(model_id)
          case model_id
          when /multimodalembedding/ then 1048
          end
        end

        def modalities_for(model_id)
          case model_id
          when /multimodalembedding/ then {
            input: %w[text image video],
            output: ['embeddings']
          }
          end
        end

        def modality_limits_for(model_id)
          return nil unless model_id.match?(/multimodalembedding/)

          {
            text: {
              max_tokens: 32,
              description: 'Text input limited to 32 tokens'
            },
            image: {
              max_count: 1,
              max_size_mb: 20,
              formats: %w[bmp gif jpeg png],
              description: 'Single image up to 20MB'
            },
            video: {
              max_duration_seconds: 120,
              formats: %w[avi flv mkv mov mp4 mpeg mpg webm wmv],
              description: 'Video up to 120 seconds'
            }
          }
        end

        def max_embedding_dimensions_for(model_id)
          case model_id
          when /multimodalembedding/ then 1408
          end
        end

        def allowed_dimensions_for(model_id)
          case model_id
          when /multimodalembedding/
            {
              text: {
                default: 1408,
                options: [128, 256, 512, 1408],
                description: 'Supports lower-dimension embeddings. Default is 1408'
              },
              image: {
                default: 1408,
                options: [128, 256, 512, 1408],
                description: 'Supports lower-dimension embeddings. Default is 1408'
              },
              video: {
                default: 1408,
                options: [1408],
                description: 'Only 1408-dimensional embeddings supported for video'
              }
            }
          end
        end

        def supports_vision?(model_id)
          model_id.match?(/multimodalembedding/)
        end

        def supports_video?(model_id)
          model_id.match?(/multimodalembedding/)
        end

        def supports_functions?(model_id)
          false if model_id.match?(/multimodalembedding/)
        end

        def model_type(model_id)
          case model_id
          when /embedding/ then 'embedding'
          else 'chat'
          end
        end

        def capabilities_for(model_id)
          return ['vision'] if model_id.match?(/multimodalembedding/)

          capabilities = ['streaming']
          capabilities << 'function_calling' if model_id.include?('gemini')
          capabilities.uniq
        end

        def supported_formats_for(model_id)
          return nil unless model_id.match?(/multimodalembedding/)

          {
            image: %w[bmp gif jpeg png],
            video: %w[avi flv mkv mov mp4 mpeg mpg webm wmv]
          }
        end

        def pricing_for(model_id)
          case model_id
          when /multimodalembedding/
            {
              text_tokens: {
                standard: {
                  input_per_million: 0.2
                }
              },
              images: {
                standard: {
                  input: 0.0001
                }
              }
            }
          end
        end

        def determine_metadata(model_id)
          case model_id
          when /multimodalembedding/
            {
              source: 'known_models',
              model_type: 'embedding',
              modality_limits: modality_limits_for(model_id),
              max_embedding_dimensions: max_embedding_dimensions_for(model_id),
              allowed_dimensions: allowed_dimensions_for(model_id),
              supported_formats: supported_formats_for(model_id),
              detailed_pricing: {
                text: {
                  per_1k_characters: 0.0002,
                  per_million_characters: 0.2,
                  description: 'Text embedding pricing'
                },
                image: {
                  per_image: 0.0001,
                  per_1000_images: 0.1,
                  per_million_images: 100.0,
                  description: 'Image embedding pricing'
                },
                video: {
                  plus: {
                    per_second: 0.0020,
                    per_1000_seconds: 2.0,
                    per_million_seconds: 2000.0,
                    embeddings_per_minute: 15,
                    description: 'Up to 15 embeddings per minute of video'
                  },
                  standard: {
                    per_second: 0.0010,
                    per_1000_seconds: 1.0,
                    per_million_seconds: 1000.0,
                    embeddings_per_minute: 8,
                    description: 'Up to 8 embeddings per minute of video'
                  },
                  essential: {
                    per_second: 0.0005,
                    per_1000_seconds: 0.5,
                    per_million_seconds: 500.0,
                    embeddings_per_minute: 4,
                    description: 'Up to 4 embeddings per minute of video'
                  }
                }
              }
            }
          else
            { source: 'known_models' }
          end
        end
      end
    end
  end
end
