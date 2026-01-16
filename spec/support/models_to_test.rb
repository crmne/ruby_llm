# frozen_string_literal: true

CHAT_MODELS = [
  { provider: :bedrock, model: 'claude-3-5-haiku' },
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

THINKING_MODELS = [
  { provider: :anthropic, model: 'claude-haiku-4-5' },
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

PDF_MODELS = [
  { provider: :anthropic, model: 'claude-haiku-4-5' },
  { provider: :bedrock, model: 'claude-3-7-sonnet' },
  { provider: :gemini, model: 'gemini-2.5-flash' },
  { provider: :openai, model: 'gpt-5-nano' },
  { provider: :openrouter, model: 'gemini-2.5-flash' },
  { provider: :vertexai, model: 'gemini-2.5-flash' }
].freeze

VISION_MODELS = [
  { provider: :anthropic, model: 'claude-haiku-4-5' },
  { provider: :bedrock, model: 'claude-sonnet-4-5' },
  { provider: :gemini, model: 'gemini-2.5-flash' },
  { provider: :mistral, model: 'pixtral-12b-latest' },
  { provider: :ollama, model: 'granite3.2-vision' },
  { provider: :openai, model: 'gpt-5-nano' },
  { provider: :openrouter, model: 'claude-haiku-4-5' },
  { provider: :vertexai, model: 'gemini-2.5-flash' },
  { provider: :xai, model: 'grok-2-vision-1212' }
].freeze

VIDEO_MODELS = [
  { provider: :gemini, model: 'gemini-2.5-flash' },
  { provider: :vertexai, model: 'gemini-2.5-flash' }
].freeze

AUDIO_MODELS = [
  { provider: :openai, model: 'gpt-4o-mini-audio-preview' },
  { provider: :gemini, model: 'gemini-2.5-flash' }
].freeze

EMBEDDING_MODELS = [
  { provider: :gemini, model: 'text-embedding-004' },
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
