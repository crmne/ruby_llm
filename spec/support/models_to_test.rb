# frozen_string_literal: true

CHAT_MODELS = [
  { provider: :openrouter, model: 'claude-haiku-4-5' },
  { provider: :bedrock, model: 'claude-3-5-haiku' },
  { provider: :deepseek, model: 'deepseek-chat' },
  { provider: :gemini, model: 'gemini-2.5-flash' },
  { provider: :gpustack, model: 'qwen3' },
  { provider: :mistral, model: 'mistral-small-latest' },
  { provider: :ollama, model: 'qwen3' },
  { provider: :openai, model: 'gpt-4.1-nano' },
  { provider: :openrouter, model: 'claude-haiku-4-5' },
  { provider: :perplexity, model: 'sonar' },
  { provider: :vertexai, model: 'gemini-2.5-flash' }
].freeze

PDF_MODELS = [
  { provider: :anthropic, model: 'claude-haiku-4-5' },
  { provider: :bedrock, model: 'claude-3-7-sonnet' },
  { provider: :gemini, model: 'gemini-2.5-flash' },
  { provider: :openai, model: 'gpt-4.1-nano' },
  { provider: :openrouter, model: 'gemini-2.5-flash' },
  { provider: :vertexai, model: 'gemini-2.5-flash' }
].freeze

VISION_MODELS = [
  { provider: :anthropic, model: 'claude-haiku-4-5' },
  { provider: :bedrock, model: 'claude-sonnet-4-5' },
  { provider: :gemini, model: 'gemini-2.5-flash' },
  { provider: :mistral, model: 'pixtral-12b-latest' },
  { provider: :ollama, model: 'granite3.2-vision' },
  { provider: :openai, model: 'gpt-4.1-nano' },
  { provider: :openrouter, model: 'claude-haiku-4-5' },
  { provider: :vertexai, model: 'gemini-2.5-flash' }
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
  { provider: :openai, model: 'text-embedding-3-small' },
  { provider: :mistral, model: 'mistral-embed' },
  { provider: :vertexai, model: 'text-embedding-004' }
].freeze

TRANSCRIPTION_MODELS = [
  { provider: :openai, model: 'whisper-1' },
  { provider: :openai, model: 'gpt-4o-transcribe-diarize' },
  { provider: :gemini, model: 'gemini-2.5-flash' },
  { provider: :vertexai, model: 'gemini-2.5-flash' }
].freeze
