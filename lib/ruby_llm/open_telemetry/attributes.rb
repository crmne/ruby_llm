# frozen_string_literal: true

module RubyLLM
  class OpenTelemetry
    module Attributes # :nodoc:
      OPERATIONS = {
        'chat.ruby_llm' => 'chat',
        'embedding.ruby_llm' => 'embeddings',
        'image.ruby_llm' => 'generate_content',
        'speech.ruby_llm' => 'generate_content',
        'transcription.ruby_llm' => 'transcription',
        'ocr.ruby_llm' => 'ocr',
        'rerank.ruby_llm' => 'rerank',
        'moderation.ruby_llm' => 'moderation',
        'judgment.ruby_llm' => 'judgment',
        'tool_call.ruby_llm' => 'execute_tool',
        'workflow.ruby_llm' => 'invoke_workflow',
        'workflow_step.ruby_llm' => 'ruby_llm.workflow_step'
      }.freeze
      PROVIDERS = {
        'bedrock' => 'aws.bedrock',
        'azure' => 'azure.ai.openai',
        'gemini' => 'gcp.gen_ai',
        'vertexai' => 'gcp.vertex_ai',
        'mistral' => 'mistral_ai',
        'xai' => 'x_ai'
      }.freeze
      INTERNAL_OPERATIONS = %w[execute_tool invoke_workflow ruby_llm.workflow_step].freeze

      module_function

      def span_name(operation, payload)
        target = case operation
                 when 'execute_tool' then payload[:tool_name]
                 when 'invoke_workflow' then payload[:workflow_name]
                 when 'ruby_llm.workflow_step' then payload[:workflow_step_name]
                 else payload[:model]
                 end
        [operation, target].compact.join(' ')
      end

      def span_kind(operation)
        INTERNAL_OPERATIONS.include?(operation) ? :internal : :client
      end

      def request(operation, payload, event:)
        return workflow(operation, payload) if operation.include?('workflow')
        return tool(payload) if operation == 'execute_tool'

        {
          'gen_ai.operation.name' => operation,
          'gen_ai.provider.name' => PROVIDERS.fetch(payload[:provider], payload[:provider]),
          'gen_ai.request.model' => payload[:model],
          'gen_ai.request.temperature' => payload[:temperature],
          'gen_ai.request.max_tokens' => payload[:max_output_tokens],
          'gen_ai.request.stream' => (true if payload[:streaming]),
          'gen_ai.embeddings.dimension.count' => payload[:dimensions],
          'gen_ai.output.type' => output_type(event, payload)
        }.compact
      end

      def output_type(event, payload)
        return 'json' if payload[:schema]
        return 'image' if event == 'image.ruby_llm'
        return 'speech' if event == 'speech.ruby_llm'

        nil
      end

      def response(payload)
        response = payload[:response]
        attributes = {
          'gen_ai.response.model' => payload[:response_model],
          'gen_ai.response.finish_reasons' => ([response.finish_reason.to_s] if response&.finish_reason)
        }.compact
        attributes.merge!(tokens(payload[:response_tokens] || payload[:tokens])) if payload[:tokens]
        attributes
      end

      def tokens(tokens)
        input = [tokens.input, tokens.cache_read, tokens.cache_write].compact
        {
          'gen_ai.usage.input_tokens' => (input.sum unless input.empty?),
          'gen_ai.usage.output_tokens' => tokens.output,
          'gen_ai.usage.cache_read.input_tokens' => tokens.cache_read,
          'gen_ai.usage.cache_write.input_tokens' => tokens.cache_write,
          'gen_ai.usage.reasoning.output_tokens' => tokens.thinking
        }.compact
      end

      def tool(payload)
        {
          'gen_ai.operation.name' => 'execute_tool',
          'gen_ai.tool.name' => payload[:tool_name],
          'gen_ai.tool.call.id' => payload[:tool_call_id],
          'gen_ai.tool.type' => 'function'
        }.compact
      end

      def workflow(operation, payload)
        {
          'gen_ai.operation.name' => (operation unless operation == 'ruby_llm.workflow_step'),
          'gen_ai.workflow.name' => payload[:workflow_name],
          'ruby_llm.workflow.id' => payload[:workflow_id],
          'ruby_llm.workflow.step.name' => payload[:workflow_step_name],
          'ruby_llm.workflow.step.id' => payload[:workflow_step_id]
        }.compact
      end
    end
  end
end
