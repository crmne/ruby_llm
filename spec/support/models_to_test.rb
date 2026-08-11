# frozen_string_literal: true

SKIP_LOCAL_PROVIDER_TESTS = ENV['SKIP_LOCAL_PROVIDER_TESTS'].to_s.match?(/\A(1|true|yes)\z/i)
LOCAL_PROVIDER_SLUGS = %i[ollama gpustack].freeze

def filter_local_providers(models)
  SKIP_LOCAL_PROVIDER_TESTS ? models.reject { |model| LOCAL_PROVIDER_SLUGS.include?(model[:provider]) } : models
end

def each_model(models)
  models.each { |model_info| yield model_info[:provider], model_info[:model], model_info }
end

chat_models = [
  { provider: :anthropic, model: 'claude-haiku-4-5' },
  { provider: :azure, model: 'grok-4-1-fast-non-reasoning' },
  { provider: :bedrock, model: 'amazon.nova-2-lite-v1:0' },
  { provider: :deepseek, model: 'deepseek-chat' },
  { provider: :gemini, model: 'gemini-2.5-flash' },
  { provider: :gpustack, model: 'qwen3' },
  { provider: :mistral, model: 'mistral-small-latest' },
  { provider: :ollama, model: 'qwen3' },
  { provider: :openai, model: 'gpt-5-nano' },
  { provider: :openrouter, model: 'claude-haiku-4-5' },
  { provider: :perplexity, model: 'sonar' },
  { provider: :vertexai, model: 'gemini-2.5-flash' },
  { provider: :xai, model: 'grok-4-1-fast-non-reasoning' }
].freeze
CHAT_MODELS = filter_local_providers(chat_models).freeze

structured_output_models = [
  { provider: :anthropic, model: 'claude-haiku-4-5' },
  { provider: :azure, model: 'grok-4-1-fast-non-reasoning' },
  { provider: :bedrock, model: 'claude-haiku-4-5' },
  { provider: :gemini, model: 'gemini-3-flash-preview' },
  { provider: :mistral, model: 'mistral-small-latest' },
  { provider: :openai, model: 'gpt-5-nano' },
  { provider: :openrouter, model: 'claude-haiku-4-5' },
  { provider: :vertexai, model: 'gemini-3-flash-preview' },
  { provider: :xai, model: 'grok-4-1-fast-non-reasoning' }
]
STRUCTURED_OUTPUT_MODELS = filter_local_providers(structured_output_models).freeze

thinking_models = [
  { provider: :anthropic, model: 'claude-haiku-4-5' },
  { provider: :azure, model: 'gpt-5-nano' },
  { provider: :bedrock, model: 'claude-haiku-4-5' },
  { provider: :deepseek, model: 'deepseek-reasoner' },
  { provider: :gemini, model: 'gemini-3-flash-preview' },
  { provider: :gpustack, model: 'qwen3' },
  { provider: :mistral, model: 'mistral-small-latest' },
  { provider: :ollama, model: 'qwen3' },
  { provider: :openai, model: 'gpt-5.4' },
  { provider: :openrouter, model: 'claude-haiku-4-5' },
  { provider: :perplexity, model: 'sonar-reasoning-pro' },
  { provider: :vertexai, model: 'gemini-3-flash-preview' },
  { provider: :xai, model: 'grok-3-mini' }
].freeze
THINKING_MODELS = filter_local_providers(thinking_models).freeze

MULTIMODAL_TOOL_RESULT_MODELS = [
  { provider: :anthropic, model: 'claude-haiku-4-5' },
  { provider: :azure, model: 'grok-4-1-fast-non-reasoning', pdf: false },
  { provider: :bedrock, model: 'claude-sonnet-4-5' },
  { provider: :gemini, model: 'gemini-3-flash-preview' },
  { provider: :gemini, model: 'gemini-2.5-flash' },
  { provider: :mistral, model: 'mistral-small-latest', pdf: false },
  { provider: :openai, model: 'gpt-5-nano' },
  { provider: :openrouter, model: 'gemini-2.5-flash' },
  { provider: :vertexai, model: 'gemini-3-flash-preview' },
  { provider: :vertexai, model: 'gemini-2.5-flash' },
  { provider: :xai, model: 'grok-4-1-fast-non-reasoning', pdf: false }
].freeze

PDF_MODELS = [
  { provider: :anthropic, model: 'claude-haiku-4-5' },
  { provider: :bedrock, model: 'claude-sonnet-4-5' },
  { provider: :gemini, model: 'gemini-2.5-flash' },
  { provider: :openai, model: 'gpt-5-nano' },
  { provider: :openrouter, model: 'gemini-2.5-flash' },
  { provider: :vertexai, model: 'gemini-2.5-flash' }
].freeze

DOCUMENT_MODELS = [
  { provider: :bedrock, model: 'claude-sonnet-4-5' },
  { provider: :mistral, model: 'mistral-small-latest' },
  { provider: :perplexity, model: 'sonar-pro' }
].freeze

SPREADSHEET_MODELS = [
  { provider: :bedrock, model: 'claude-sonnet-4-5' }
].freeze

vision_models = [
  { provider: :anthropic, model: 'claude-haiku-4-5' },
  { provider: :azure, model: 'grok-4-1-fast-non-reasoning' },
  { provider: :bedrock, model: 'claude-sonnet-4-5' },
  { provider: :gemini, model: 'gemini-2.5-flash' },
  { provider: :mistral, model: 'pixtral-12b' },
  { provider: :ollama, model: 'granite3.2-vision' },
  { provider: :openai, model: 'gpt-5-nano' },
  { provider: :openrouter, model: 'claude-haiku-4-5' },
  { provider: :vertexai, model: 'gemini-2.5-flash' },
  { provider: :xai, model: 'grok-4-1-fast-non-reasoning' }
].freeze
VISION_MODELS = filter_local_providers(vision_models).freeze

VIDEO_MODELS = [
  { provider: :bedrock, model: 'amazon.nova-2-lite-v1:0' },
  { provider: :gemini, model: 'gemini-2.5-flash' },
  { provider: :vertexai, model: 'gemini-2.5-flash' }
].freeze

AUDIO_MODELS = [
  { provider: :bedrock, model: 'mistral.voxtral-mini-3b-2507' },
  { provider: :openai, model: 'gpt-audio-mini' },
  { provider: :gemini, model: 'gemini-2.5-flash' },
  { provider: :mistral, model: 'voxtral-small-latest' }
].freeze

EMBEDDING_MODELS = [
  { provider: :azure, model: 'Cohere-embed-v3-english' },
  { provider: :bedrock, model: 'amazon.titan-embed-text-v2:0' },
  { provider: :gemini, model: 'gemini-embedding-001' },
  { provider: :mistral, model: 'mistral-embed' },
  { provider: :openai, model: 'text-embedding-3-small' },
  { provider: :openrouter, model: 'openai/text-embedding-3-small' },
  { provider: :vertexai, model: 'text-embedding-004' }
].freeze

# Vertex AI TTS models (gemini-2.5-*-tts) 404 on the global and us-central1
# endpoints, so speech is exercised through the Gemini API instead.
SPEECH_MODELS = [
  { provider: :gemini, model: 'gemini-2.5-flash-preview-tts' },
  { provider: :mistral, model: 'voxtral-mini-tts-latest', voice: 'en_paul_neutral' },
  { provider: :openai, model: 'gpt-4o-mini-tts' },
  { provider: :openrouter, model: 'hexgrad/kokoro-82m', voice: 'af_bella' },
  { provider: :xai, model: 'grok-tts' }
].freeze

TRANSCRIPTION_MODELS = [
  { provider: :gemini, model: 'gemini-2.5-flash' },
  { provider: :mistral, model: 'voxtral-mini-latest' },
  { provider: :openai, model: 'gpt-4o-transcribe-diarize' },
  { provider: :openai, model: 'whisper-1' },
  { provider: :openrouter, model: 'openai/gpt-4o-mini-transcribe' },
  { provider: :vertexai, model: 'gemini-2.5-flash' },
  { provider: :xai, model: 'grok-stt' }
].freeze

VIDEO_GENERATION_MODELS = [
  { provider: :gemini, model: 'veo-3.1-lite-generate-preview',
    provider_options: { parameters: { durationSeconds: 4 } } }
].freeze

image_generation_models = [
  { provider: :openai, model: 'gpt-image-1', supports_size: false },
  { provider: :gemini, model: 'imagen-4.0-generate-001', supports_size: false },
  { provider: :gemini, model: 'gemini-3.1-flash-lite-image', supports_size: false },
  { provider: :vertexai, model: 'gemini-3.1-flash-lite-image', supports_size: false },
  { provider: :openrouter, model: 'google/gemini-3.1-flash-lite-image', supports_size: false },
  { provider: :xai, model: 'grok-imagine-image', supports_size: false }
].freeze
IMAGE_GENERATION_MODELS = filter_local_providers(image_generation_models).freeze
