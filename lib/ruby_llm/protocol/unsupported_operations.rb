# frozen_string_literal: true

module RubyLLM
  class Protocol
    # Turns the NotImplementedError of a missing seam into an Error naming the
    # provider and the operation. It wraps only Protocol's own methods, so a
    # subclass that replaces an operation answers for its own errors.
    module UnsupportedOperations # :nodoc:
      OPERATIONS = {
        tool_approval_response: 'remote tool approvals',
        render: 'chat',
        count_tokens: 'token counting',
        tokenize: 'text tokenization',
        compact: 'manual compaction',
        list_models: 'model listing',
        embed: 'embeddings',
        moderate: 'moderation',
        paint: 'image generation',
        animate_later: 'video generation',
        find_video_job: 'video generation',
        refresh_video_job: 'video generation',
        speak: 'speech generation',
        transcribe: 'transcription',
        ocr: 'OCR',
        rerank: 'reranking',
        judge: 'judgments',
        cache_content: 'explicit content caching',
        find_cache: 'explicit content caching',
        delete_cache: 'explicit content caching',
        extend_cache: 'explicit content caching'
      }.freeze

      OPERATIONS.each do |operation, label|
        define_method(operation) do |*args, **options, &block|
          super(*args, **options, &block)
        rescue NotImplementedError
          raise Error, "#{@provider.name} doesn't support #{label}"
        end
      end
    end
  end
end
