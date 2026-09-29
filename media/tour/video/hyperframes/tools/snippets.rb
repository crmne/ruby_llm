{
  # Source: developers.openai.com/api/docs/guides/text.md (curl + response shape)
  "b_ask" => <<~'SH',
    curl https://api.openai.com/v1/responses \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $OPENAI_API_KEY" \
      -d '{
        "model": "gpt-5.6",
        "input": "Write a one-sentence bedtime story about a unicorn."
      }'

    # the text is buried in the output array:
    # "output": [{ "type": "message", "role": "assistant",
    #   "content": [{ "type": "output_text", "text": "..." }] }]
    # never assume output[0]; find the "message" item first
  SH
  # 2. Conversation. Source: developers.openai.com/api/docs/guides/conversation-state.md (Ruby, manual history)
  "b_convo" => <<~'RUBY',
    client = OpenAI::Client.new
    history = [{ role: :user, content: "Write a one-sentence bedtime story about a unicorn." }]

    first = client.responses.create(
      model: "gpt-5.6",
      input: history,
      store: false
    )
    puts(first.output_text)

    history.concat(first.output)
    history << { role: :user, content: "Tell me another." }

    second = client.responses.create(model: "gpt-5.6", input: history, store: false)
    puts(second.output_text)
  RUBY
  # 3. Streaming. Source: github.com/openai/openai-ruby examples/responses/streaming_basic.rb
  "b_stream" => <<~'RUBY',
    client = OpenAI::Client.new
    stream = client.responses.stream(input: "Write a haiku about Ruby.", model: "gpt-5.6")

    streamed_text = String.new
    completed_response_id = ""
    stream.each do |event|
      case event
      when OpenAI::Streaming::ResponseTextDeltaEvent
        streamed_text << event.delta
        print(event.delta)
      when OpenAI::Streaming::ResponseTextDoneEvent
        puts("\n--------------------------")
      when OpenAI::Streaming::ResponseCompletedEvent
        completed_response_id = event.response.id
      end
    end
  RUBY
  # docs/_advanced/rails-streaming.md (ChatStreamJob, guards trimmed)
  "a_stream_job" => <<~'RUBY',
    class ChatStreamJob < ApplicationJob
      def perform(chat_id)
        chat = Chat.find(chat_id)

        chat.complete do |chunk|
          message = chat.messages.last
          message.broadcast_append_chunk(chunk.content)
        end
      end
    end
  RUBY

  "a_block1" => <<~'RUBY',
    chat = RubyLLM.chat
    chat.ask "Write a one-sentence bedtime story about a unicorn."
  RUBY
  "a_block2" => %q{chat.ask "Tell me another."},
  "a_block3" => <<~'RUBY',
    chat.ask "Write a haiku about Ruby." do |chunk|
      print chunk.content
    end
  RUBY

  # 1. First ask. Source: developers.openai.com/api/docs/guides/text.md (curl + response shape)
  "a_ask" => %q{RubyLLM.chat.ask "Write a one-sentence bedtime story about a unicorn."},

  # 2. Conversation. Source: developers.openai.com/api/docs/guides/conversation-state.md (Ruby, manual history)
  "a_convo" => <<~'RUBY',
    chat = RubyLLM.chat
    chat.ask "Tell me a joke."
    chat.ask "Tell me another."
  RUBY

  # 3. Streaming. Source: github.com/openai/openai-ruby examples/responses/streaming_basic.rb
  "a_stream" => <<~'RUBY',
    chat.ask "Write a haiku about Ruby." do |chunk|
      print chunk.content
    end
  RUBY
  # 4. Files. Sources: developers.openai.com/api/docs/guides/images-vision.md and file-inputs.md (Ruby)
  "b_files" => <<~'RUBY',
    require "base64"
    image = Base64.strict_encode64(File.binread("image.png"))
    pdf_data = Base64.strict_encode64(File.binread("report.pdf"))

    response = client.responses.create(
      model: "gpt-5.6",
      input: [{ role: :user, content: [
        { type: :input_text, text: "What's in these files?" },
        { type: :input_image, detail: :auto,
          image_url: "data:image/png;base64,#{image}" },
        { type: :input_file, filename: "report.pdf",
          file_data: "data:application/pdf;base64,#{pdf_data}" }
      ] }]
    )
  RUBY
  "a_files" => %Q{chat.ask "What's in these files?",
  with: ["image.png", "report.pdf"]},
  "a_files_1" => %Q{chat.ask "What's in this image?",
  with: "image.png"},
  "a_files_2" => %Q{chat.ask "What's in this image?",
  with: "https://example.com/eiffel_tower.jpg"},
  "a_files_3" => %Q{chat.ask "Analyze these files",
  with: ["diagram.png", "demo.mp4", "notes.txt"]},

  # 5. Tools. Source: developers.openai.com/api/docs/guides/function-calling.md (Ruby, condensed)
  "b_tools" => <<~'RUBY',
    tools = [{
      type: :function, name: "get_weather",
      description: "Get current weather for a location.",
      parameters: { type: :object,
        properties: { latitude: { type: :number }, longitude: { type: :number } },
        required: ["latitude", "longitude"], additionalProperties: false },
      strict: true
    }]
    first_response = client.responses.create(model: "gpt-5.6",
      input: "What's the weather in Berlin?", tools: tools)
    function_call = first_response.output.find do |item|
      item.is_a?(OpenAI::Models::Responses::ResponseFunctionToolCall) &&
        item.name == "get_weather"
    end
    arguments = JSON.parse(function_call.arguments, symbolize_names: true)
    result = get_weather(**arguments)
    response = client.responses.create(model: "gpt-5.6",
      previous_response_id: first_response.id,
      input: [{ type: :function_call_output, call_id: function_call.call_id,
                output: JSON.generate(result) }],
      tools: tools)
    puts(response.output_text)
  RUBY
  "a_tools" => <<~'RUBY',
    class Weather < RubyLLM::Tool
      description "Get current weather for a location"

      def execute(latitude:, longitude:)
        Forecast.current(latitude, longitude)
      end
    end

    chat.with_tools(Weather).ask "What's the weather in Berlin?"
  RUBY

  # 6. MCP. Source: modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http
  "b_mcp" => <<~'SH',
    POST https://mcp.linear.app/mcp
    Authorization: Bearer $LINEAR_API_KEY
    Content-Type: application/json
    Accept: application/json, text/event-stream
    MCP-Protocol-Version: 2026-07-28
    Mcp-Method: tools/call
    Mcp-Name: list_issues

    { "jsonrpc": "2.0", "id": 3, "method": "tools/call",
      "params": { "name": "list_issues", "arguments": { ... },
        "_meta": {
          "io.modelcontextprotocol/protocolVersion": "2026-07-28",
          "io.modelcontextprotocol/clientInfo": { "name": "app", "version": "1.0.0" },
          "io.modelcontextprotocol/clientCapabilities": {} } } }
    # plus: tools/list, map each inputSchema to your model's tool format,
    # parse JSON or SSE replies, fall back to initialize for older servers
  SH
  "a_mcp" => <<~'RUBY',
    class Linear < RubyLLM::MCP
      url "https://mcp.linear.app/mcp"
      bearer_token ENV.fetch("LINEAR_API_KEY")
    end

    chat.with_mcp(Linear).ask "What's blocking the release?"
  RUBY
  "m_github" => <<~'RUBY',
    class GitHub < RubyLLM::MCP
      url "https://api.githubcopilot.com/mcp/"
      bearer_token ENV.fetch("GITHUB_TOKEN")
    end
  RUBY
  # Notion: developers.notion.com/guides/mcp/get-started-with-mcp (OAuth only); oauth macro: docs/_core_features/mcp.md, spec/ruby_llm/mcp/oauth_spec.rb
  "m_notion" => <<~'RUBY',
    class Notion < RubyLLM::MCP
      url "https://mcp.notion.com/mcp"
      oauth
    end
  RUBY
  # Atlassian Rovo: support.atlassian.com/atlassian-rovo-mcp-server/docs/configuring-authentication-via-api-token/
  "m_atlassian" => <<~'RUBY',
    class Atlassian < RubyLLM::MCP
      url "https://mcp.atlassian.com/v2/mcp"
      bearer_token ENV.fetch("ATLASSIAN_API_KEY")
    end
  RUBY
  # Sentry: mcp.sentry.dev (OAuth only)
  "m_sentry" => <<~'RUBY',
    class Sentry < RubyLLM::MCP
      url "https://mcp.sentry.dev/mcp"
      oauth
    end
  RUBY

  # 7. Structured output. Source: developers.openai.com/api/docs/guides/structured-outputs.md (Ruby)
  "b_schema" => <<~'RUBY',
    product_schema = {
      type: :object,
      properties: {
        name: { type: :string },
        price: { type: :number },
        features: { type: :array, items: { type: :string } }
      },
      required: %w[name price features],
      additionalProperties: false
    }
    response = client.responses.create(
      model: "gpt-5.6",
      input: [{ role: :user, content: "Analyze this product: #{text}" }],
      text: { format: { type: :json_schema, name: "product",
                        strict: true, schema: product_schema } }
    )
    product = JSON.parse(response.output_text)
  RUBY
  "a_schema" => <<~'RUBY',
    class ProductSchema < Schematist::Schema
      string :name
      number :price
      array :features do
        string
      end
    end

    response = chat.with_schema(ProductSchema)
      .ask "Analyze this product", with: "product.txt"
    response.parsed
  RUBY
  "a_parsed" => <<~'RUBY',
    {
      "name" => "Ruby Mug",
      "price" => 18.0,
      "features" => [
        "Ceramic", "12 oz", "Dishwasher safe"
      ]
    }
  RUBY

  # 8. Judge. Source: docs/_core_features/judgments.md
  "a_judge" => <<~'RUBY',
    class TicketTriage < RubyLLM::Judge
      model "jev-latest"
      probability :urgent, "Does this need attention today?"
      score :frustration, "How frustrated is the customer?",
        ["Calm", "Frustrated", "Angry"]
    end

    judgment = TicketTriage.judge("Charged twice for my Ruby Mug. Refund me today!")
    judgment.urgent.probability
  RUBY

  # 9. Agent with approval. Sources: docs/_core_features/tool-execution.md, docs/_advanced/agentic-workflows.md
  "a_refund" => <<~'RUBY',
    class IssueRefund < RubyLLM::Tool
      description "Issues a refund for an order"
      requires_approval

      def execute(order_id:) = Refunds.issue!(order_id)
    end

    class SupportAgent < RubyLLM::Agent
      model "claude-sonnet-5"
      instructions "Resolve billing tickets."
      tools IssueRefund
    end
  RUBY
  "a_refund_run" => <<~'RUBY',
    RubyLLM.workflow("Billing ticket") do |workflow|
      agent = SupportAgent.new
      workflow.step("Resolve") { agent.ask "Refund order 42" }

      agent.approve(agent.pending_approvals.first)
      agent.complete
    end
  RUBY

  # 10. Providers.
  # Anthropic: platform.claude.com/docs/en/get-started (curl)
  "b_anthropic" => <<~'SH',
    curl https://api.anthropic.com/v1/messages \
      -H "content-type: application/json" \
      -H "x-api-key: $ANTHROPIC_API_KEY" \
      -H "anthropic-version: 2023-06-01" \
      -d '{
        "model": "claude-opus-5-5",
        "max_tokens": 1000,
        "messages": [
          {"role": "user", "content": "Hello, Claude"}
        ]
      }'
    # text is at .content[0].text
  SH
  # Gemini: ai.google.dev/gemini-api/docs/generate-content (curl)
  "b_gemini" => <<~'SH',
    curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent" \
      -H "x-goog-api-key: $GEMINI_API_KEY" \
      -H 'Content-Type: application/json' \
      -X POST \
      -d '{
        "contents": [
          { "parts": [ { "text": "Explain how AI works in a few words" } ] }
        ]
      }'
    # text is at .candidates[0].content.parts[0].text
  SH
  # Bedrock: docs.aws.amazon.com/bedrock/latest/userguide/bedrock-runtime_example_bedrock-runtime_Converse_AnthropicClaude_section.html
  "b_bedrock" => <<~'PY',
    import boto3
    from botocore.exceptions import ClientError

    client = boto3.client("bedrock-runtime", region_name="us-east-1")
    model_id = "anthropic.claude-sonnet-5"
    conversation = [
        {"role": "user", "content": [{"text": "Describe 'hello world' in one line."}]}
    ]
    try:
        response = client.converse(
            modelId=model_id,
            messages=conversation,
            inferenceConfig={"maxTokens": 512, "temperature": 0.5, "topP": 0.9},
        )
        print(response["output"]["message"]["content"][0]["text"])
    except (ClientError, Exception) as e:
        print(f"ERROR: Can't invoke '{model_id}'. Reason: {e}"); exit(1)
  PY
  "a_anthropic" => %q{RubyLLM.chat(model: "claude-opus-5-5")},
  "a_gemini" => %q{RubyLLM.chat(model: "gemini-3.8-flash")},
  "a_bedrock" => %q{RubyLLM.chat(model: "claude-sonnet-5", provider: :bedrock)},

  # 11. Operations.
  # OpenAI TTS: developers.openai.com/api/docs/guides/text-to-speech.md
  "b_speak" => <<~'SH',
    curl https://api.openai.com/v1/audio/speech \
      -H "Authorization: Bearer $OPENAI_API_KEY" \
      -H "Content-Type: application/json" \
      -d '{
        "model": "gpt-4o-mini-tts",
        "input": "Welcome to the show!",
        "voice": "coral"
      }' \
      --output speech.mp3
  SH
  # OpenAI STT: developers.openai.com/api/docs/guides/speech-to-text.md
  "b_transcribe" => <<~'SH',
    curl --request POST \
      --url https://api.openai.com/v1/audio/transcriptions \
      --header "Authorization: Bearer $OPENAI_API_KEY" \
      --header 'Content-Type: multipart/form-data' \
      --form file=@speech.mp3 \
      --form model=gpt-transcribe
    # {"text": "..."}
  SH
  "a_speak" => %q{RubyLLM.speak("Welcome to the show!").save("speech.mp3")},
  "a_transcribe" => %q{RubyLLM.transcribe("speech.mp3").text},
  # OpenAI images: developers.openai.com/api/docs/guides/image-generation.md
  "b_paint" => <<~'SH',
    curl -X POST "https://api.openai.com/v1/images/generations" \
      -H "Authorization: Bearer $OPENAI_API_KEY" \
      -H "Content-type: application/json" \
      -d '{
        "model": "gpt-image-2",
        "prompt": "A red panda writing Ruby"
      }' | jq -r '.data[0].b64_json' | base64 --decode > panda.png
  SH
  # xAI video: docs.x.ai/developers/model-capabilities/video/generation
  "b_animate" => <<~'SH',
    curl -X POST https://api.x.ai/v1/videos/generations \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $XAI_API_KEY" \
      -d '{"model": "grok-imagine-video-1.5", "prompt": "A red panda writing Ruby"}'
    # {"request_id": "d97415a1-..."}
    # poll until status is "done" (pending | done | expired | failed)
    curl -X GET "https://api.x.ai/v1/videos/$REQUEST_ID" \
      -H "Authorization: Bearer $XAI_API_KEY"
    # download .video.url promptly: it is temporary
    curl -o panda.mp4 "$VIDEO_URL"
  SH
  "a_paint" => %q{RubyLLM.paint("A red panda writing Ruby").save("panda.png")},
  "a_animate" => %q{RubyLLM.animate("A red panda writing Ruby").save("panda.mp4")},
  # OpenAI embeddings: developers.openai.com/api/docs/guides/embeddings.md
  "b_embed" => <<~'SH',
    curl https://api.openai.com/v1/embeddings \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $OPENAI_API_KEY" \
      -d '{
        "input": "Ruby is elegant and expressive",
        "model": "text-embedding-3-small"
      }'
    # .data[0].embedding
  SH
  # Cohere rerank: docs.cohere.com/reference/rerank
  "b_rerank" => <<~'SH',
    curl --request POST \
      --url https://api.cohere.com/v2/rerank \
      --header 'content-type: application/json' \
      --header "Authorization: bearer $CO_API_KEY" \
      --data '{
        "model": "rerank-v3.5",
        "query": "How do I reset my password?",
        "documents": ["Reset your password in Settings.", "Invoices arrive by email."],
        "top_n": 2
      }'
    # {"results":[{"index":0,"relevance_score":0.98}, ...]}
  SH
  "a_embed" => %q{RubyLLM.embed("Ruby is elegant and expressive").vectors},
  "a_rerank" => %q{RubyLLM.rerank("How do I reset my password?", documents, model: "rerank-v3.5")},
  # Mistral OCR: docs.mistral.ai/capabilities/document_ai/basic_ocr/
  "b_ocr" => <<~'SH',
    curl https://api.mistral.ai/v1/ocr \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${MISTRAL_API_KEY}" \
      -d '{
        "model": "mistral-ocr-latest",
        "document": {
            "type": "document_url",
            "document_url": "data:application/pdf;base64,<base64_pdf>"
        }
      }' -o ocr_output.json
    # text is at .pages[i].markdown
  SH
  # OpenAI moderation: developers.openai.com/api/docs/guides/moderation.md (Ruby)
  "b_moderate" => <<~'RUBY',
    moderation = client.moderations.create(
      model: OpenAI::Models::ModerationModel::OMNI_MODERATION_LATEST,
      input: "Some user-generated content"
    )
    puts(moderation.results.fetch(0).flagged)
  RUBY
  "a_ocr" => %q{RubyLLM.ocr("contract.pdf").markdown},
  "a_moderate" => %q{RubyLLM.moderate("Some user-generated content").flagged?},

  # 13. Rails
  "a_rails" => <<~'RUBY',
    class Chat < ApplicationRecord
      acts_as_chat
    end
  RUBY

  "hello" => %q{RubyLLM.chat.ask "Hello, Ruby!"},

  # Feature cards. Sources: error-handling.md:155, prompt-caching.md:38, thinking.md:44, provider-tools.md:40,
  # citations.md:35, cost-and-usage-tracking.md:39, batches.md:48/106, tool-execution.md:114,
  # agentic-workflows.md:43, chat-request-control.md:80, tokenization.md:57, _reference/models.md:177/220
  "f_fallbacks" => %q{chat.with_fallbacks("claude-haiku-4-5")},
  "f_caching" => %q{chat.with_caching(ttl: "1h")},
  "f_thinking" => %q{chat.with_thinking(effort: :high)},
  "f_search" => %q{chat.with_provider_tools(:web_search)},
  "f_citations" => %Q{chat.with_citations
response.citations},
  "f_cost" => %Q{response.tokens.output
chat.cost.total},
  "f_batches" => %Q{batch = RubyLLM.batch(chats)
batch.cost.total},
  "f_approval" => %q{chat.approve(tool_call)},
  "f_loop" => %q{chat.step until chat.complete?},
  "f_compaction" => %q{chat.with_compaction(at: 50_000)},
  "f_tokens" => %q{chat.count_tokens("Hello!")},
  "f_models" => %Q{RubyLLM.models.find("claude-sonnet-5")
  .supports?(:vision)},

  # Response shapes, abbreviated from each provider's API reference
  "r_anthropic" => <<~'JSON',
    {
      "content": [
        { "type": "text",
          "text": "Hi!" }
      ],
      "stop_reason": "end_turn"
    }
  JSON
  "r_gemini" => <<~'JSON',
    {
      "candidates": [
        { "content": {
            "parts": [
              { "text": "Hi!" }
            ] } }
      ]
    }
  JSON
  "r_bedrock" => <<~'JSON',
    {
      "output": {
        "message": {
          "content": [
            { "text": "Hi!" }
          ] } }
    }
  JSON
}
