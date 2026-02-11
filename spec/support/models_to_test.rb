# frozen_string_literal: true

SKIP_LOCAL_PROVIDER_TESTS = ENV['SKIP_LOCAL_PROVIDER_TESTS'].to_s.match?(/\A(1|true|yes)\z/i)
LOCAL_PROVIDER_SLUGS = %i[ollama gpustack].freeze

def filter_local_providers(models)
  SKIP_LOCAL_PROVIDER_TESTS ? models.reject { |model| LOCAL_PROVIDER_SLUGS.include?(model[:provider]) } : models
end

chat_models = [
  { provider: :anthropic, model: 'claude-haiku-4-5' },
  { provider: :azure, model: 'Kimi-K2.5' },
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
  { provider: :xai, model: 'grok-4-fast-non-reasoning' }
].freeze
CHAT_MODELS = filter_local_providers(chat_models).freeze

thinking_models = [
  { provider: :anthropic, model: 'claude-haiku-4-5' },
  { provider: :azure, model: 'Kimi-K2.5' },
  { provider: :bedrock, model: 'claude-haiku-4-5' },
  { provider: :deepseek, model: 'deepseek-reasoner' },
  { provider: :gemini, model: 'gemini-3-flash-preview' },
  { provider: :gpustack, model: 'qwen3' },
  { provider: :mistral, model: 'magistral-small-latest' },
  { provider: :ollama, model: 'qwen3' },
  { provider: :openai, model: 'gpt-5' },
  { provider: :openrouter, model: 'claude-haiku-4-5' },
  { provider: :perplexity, model: 'sonar-reasoning-pro' },
  { provider: :vertexai, model: 'gemini-3-flash-preview' },
  { provider: :xai, model: 'grok-3-mini' }
].freeze
THINKING_MODELS = filter_local_providers(thinking_models).freeze

PDF_MODELS = [
  { provider: :anthropic, model: 'claude-haiku-4-5' },
  { provider: :bedrock, model: 'claude-3-7-sonnet' },
  { provider: :gemini, model: 'gemini-2.5-flash' },
  { provider: :openai, model: 'gpt-5-nano' },
  { provider: :openrouter, model: 'gemini-2.5-flash' },
  { provider: :vertexai, model: 'gemini-2.5-flash' }
].freeze

vision_models = [
  { provider: :anthropic, model: 'claude-haiku-4-5' },
  { provider: :azure, model: 'Kimi-K2.5' },
  { provider: :bedrock, model: 'claude-sonnet-4-5' },
  { provider: :gemini, model: 'gemini-2.5-flash' },
  { provider: :mistral, model: 'pixtral-12b' },
  { provider: :ollama, model: 'granite3.2-vision' },
  { provider: :openai, model: 'gpt-5-nano' },
  { provider: :openrouter, model: 'claude-haiku-4-5' },
  { provider: :vertexai, model: 'gemini-2.5-flash' },
  { provider: :xai, model: 'grok-2-vision-1212' }
].freeze
VISION_MODELS = filter_local_providers(vision_models).freeze

VIDEO_MODELS = [
  { provider: :gemini, model: 'gemini-2.5-flash' },
  { provider: :vertexai, model: 'gemini-2.5-flash' }
].freeze

AUDIO_MODELS = [
  { provider: :openai, model: 'gpt-4o-mini-audio-preview' },
  { provider: :gemini, model: 'gemini-2.5-flash' }
].freeze

EMBEDDING_MODELS = [
  { provider: :azure, model: 'Cohere-embed-v3-english' },
  { provider: :gemini, model: 'gemini-embedding-001' },
  { provider: :mistral, model: 'mistral-embed' },
  { provider: :openai, model: 'text-embedding-3-small' },
  { provider: :vertexai, model: 'text-embedding-004' }
].freeze

TRANSCRIPTION_MODELS = [
  { provider: :gemini, model: 'gemini-2.5-flash' },
  { provider: :openai, model: 'gpt-4o-transcribe-diarize' },
  { provider: :openai, model: 'whisper-1' },
  { provider: :vertexai, model: 'gemini-2.5-flash' }
].freeze
