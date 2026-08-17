---
layout: home
title: RubyLLM
nav_order: 1
description: 'RubyLLM is the Ruby-native AI framework. One beautiful, consistent API across every provider, from a one-line chat call to tools, agents, RAG, and Rails apps.'
permalink: /
redirect_from:
  - /guides/
hero:
  logo:
    light: /assets/images/logotype.svg
    dark: /assets/images/logotype_dark.svg
    alt: RubyLLM
    width: 320
    height: 110
  text: 'Build AI features <span class="home-hero-highlight">the Ruby way</span>'
  tagline: 'RubyLLM is the <em class="home-hero-tagline-highlight">Ruby-native AI framework</em>. One beautiful, consistent API across every provider, from your first line to production.'
  actions:
    - theme: brand
      class: home-button--guides
      text: Get started
      link: /getting-started/
---

<section id="demo" class="home-section home-demo-section">
  <div class="home-section-inner">
    <div class="home-hero-install home-code-grid home-code-grid--bare" markdown="1">

```sh
bundle add ruby_llm
```
{: .home-code-card }

</div>

    <div class="home-demo-frame" data-demo-video>
      <pre class="home-demo-terminal" aria-hidden="true"><code><span class="term-green">$</span> irb -r ruby_llm
<span class="term-green">&gt;&gt;</span> chat = RubyLLM.chat
<span class="term-green">&gt;&gt;</span> chat.ask "What can you do?"
=&gt; "Chat with every major model, stream replies, call your
   Ruby code as tools, return structured output, read images
   and PDFs, transcribe, speak, paint... Want the full tour?"
~ <span class="term-cursor"></span></code></pre>
      <button class="home-play-button" type="button" aria-label="RubyLLM full tour, coming soon">
        <span aria-hidden="true"></span>
      </button>
      <p class="home-demo-soon" role="status">Coming soon</p>
      <img class="home-demo-avatar" src="{{ '/assets/images/founder/carmine.jpg' | relative_url }}" alt="" aria-hidden="true">
    </div>
  </div>
</section>

<section class="home-section home-band home-models-section">
  <div class="home-section-inner">
    <h2 class="home-heading">17 providers built in. Add your own.</h2>
    <p class="home-lead">
      Move between hosted and local models without rewriting your application. Connect an OpenAI-compatible endpoint directly, or scaffold a complete provider gem with specs and CI.
    </p>

    <div class="provider-icons" aria-label="Supported AI providers">
      <a href="https://anthropic.com" target="_blank" rel="noreferrer" class="provider-logo"><img src="{{ '/assets/images/providers/anthropic-text.svg' | relative_url }}" alt="Anthropic" class="logo-wide"></a>
      <a href="https://azure.microsoft.com/products/ai-services/openai-service" target="_blank" rel="noreferrer" class="provider-logo"><img src="{{ '/assets/images/providers/azureai-color.svg' | relative_url }}" alt="Azure AI" class="logo-mark"><img src="{{ '/assets/images/providers/azureai-text.svg' | relative_url }}" alt="" class="logo-text"></a>
      <a href="https://aws.amazon.com/bedrock/" target="_blank" rel="noreferrer" class="provider-logo"><img src="{{ '/assets/images/providers/bedrock-color.svg' | relative_url }}" alt="Amazon Bedrock" class="logo-mark"><img src="{{ '/assets/images/providers/bedrock-text.svg' | relative_url }}" alt="" class="logo-text"></a>
      <a href="https://cohere.com" target="_blank" rel="noreferrer" class="provider-logo"><img src="{{ '/assets/images/providers/cohere-color.svg' | relative_url }}" alt="Cohere" class="logo-mark"><img src="{{ '/assets/images/providers/cohere-text.svg' | relative_url }}" alt="" class="logo-text"></a>
      <a href="https://deepgram.com" target="_blank" rel="noreferrer" class="provider-logo"><img src="{{ '/assets/images/providers/deepgram-text.svg' | relative_url }}" alt="Deepgram" class="logo-wide"></a>
      <a href="https://deepseek.com" target="_blank" rel="noreferrer" class="provider-logo"><img src="{{ '/assets/images/providers/deepseek-color.svg' | relative_url }}" alt="DeepSeek" class="logo-mark"><img src="{{ '/assets/images/providers/deepseek-text.svg' | relative_url }}" alt="" class="logo-text"></a>
      <a href="https://elevenlabs.io" target="_blank" rel="noreferrer" class="provider-logo"><img src="{{ '/assets/images/providers/elevenlabs-text.svg' | relative_url }}" alt="ElevenLabs" class="logo-wide"></a>
      <a href="https://ai.google.dev" target="_blank" rel="noreferrer" class="provider-logo"><img src="{{ '/assets/images/providers/gemini-color.svg' | relative_url }}" alt="Gemini" class="logo-mark"><img src="{{ '/assets/images/providers/gemini-text.svg' | relative_url }}" alt="" class="logo-text"></a>
      <a href="https://gpustack.ai" target="_blank" rel="noreferrer" class="provider-logo"><img src="{{ '/assets/images/providers/gpustack-logo.png' | relative_url }}" alt="GPUStack" class="logo-wide"></a>
      <a href="https://mistral.ai" target="_blank" rel="noreferrer" class="provider-logo"><img src="{{ '/assets/images/providers/mistral-color.svg' | relative_url }}" alt="Mistral AI" class="logo-mark"><img src="{{ '/assets/images/providers/mistral-text.svg' | relative_url }}" alt="" class="logo-text"></a>
      <a href="https://ollama.com" target="_blank" rel="noreferrer" class="provider-logo"><img src="{{ '/assets/images/providers/ollama.svg' | relative_url }}" alt="" class="logo-mark logo-mono"><span class="logo-wordmark">Ollama</span></a>
      <a href="https://ollama.com/cloud" target="_blank" rel="noreferrer" class="provider-logo"><img src="{{ '/assets/images/providers/ollama.svg' | relative_url }}" alt="" class="logo-mark logo-mono"><span class="logo-wordmark">Ollama Cloud</span></a>
      <a href="https://openai.com" target="_blank" rel="noreferrer" class="provider-logo"><img src="{{ '/assets/images/providers/openai.svg' | relative_url }}" alt="OpenAI" class="logo-mark logo-mono"><img src="{{ '/assets/images/providers/openai-text.svg' | relative_url }}" alt="" class="logo-text"></a>
      <a href="https://openrouter.ai" target="_blank" rel="noreferrer" class="provider-logo"><img src="{{ '/assets/images/providers/openrouter.svg' | relative_url }}" alt="OpenRouter" class="logo-mark logo-mono"><img src="{{ '/assets/images/providers/openrouter-text.svg' | relative_url }}" alt="" class="logo-text"></a>
      <a href="https://perplexity.ai" target="_blank" rel="noreferrer" class="provider-logo"><img src="{{ '/assets/images/providers/perplexity-color.svg' | relative_url }}" alt="Perplexity" class="logo-mark"><img src="{{ '/assets/images/providers/perplexity-text.svg' | relative_url }}" alt="" class="logo-text"></a>
      <a href="https://cloud.google.com/vertex-ai" target="_blank" rel="noreferrer" class="provider-logo"><img src="{{ '/assets/images/providers/vertexai-color.svg' | relative_url }}" alt="Vertex AI" class="logo-mark"><img src="{{ '/assets/images/providers/vertexai-text.svg' | relative_url }}" alt="" class="logo-text"></a>
      <a href="https://x.ai" target="_blank" rel="noreferrer" class="provider-logo"><img src="{{ '/assets/images/providers/xai.svg' | relative_url }}" alt="xAI" class="logo-mark logo-mono"><img src="{{ '/assets/images/providers/xai-text.svg' | relative_url }}" alt="" class="logo-text"></a>
    </div>

    <div class="home-code-grid home-model-switcher" data-model-switcher aria-label="Same RubyLLM API across providers">
{% capture model_switcher_code %}
```ruby
chat = RubyLLM.chat(model: "claude-opus-4-7")
chat.ask "Hello!"
```
{: .home-code-card .home-model-switcher-code data-title="Anthropic" data-model-switcher-code="true" }
{% endcapture %}
{{ model_switcher_code | markdownify }}
    </div>

    <p class="home-small-note home-models-note">
      Browse a refreshable registry of more than 1,400
      <a href="{{ '/available-models/' | relative_url }}">models</a>,
      <a href="{% link _core_features/cost-and-usage-tracking.md %}">track usage and costs</a>,
      or
      <a href="{% link _reference/custom-providers.md %}#generate-the-starting-point">generate a provider gem</a>
      for the service you need next.
    </p>
  </div>
</section>

<section id="code-examples" class="home-section home-code-section">
  <div class="home-section-inner">
    <h2 class="home-heading">Start with one line. Keep the same API as you grow.</h2>
    <p class="home-lead">
      Every capability is a small step from the previous one, and nothing gets rewritten in between.
    </p>
  </div>

  <div class="home-steps">
    <div class="home-step">
      <div class="home-step-text">
        <h3 class="home-step-title">Just ask</h3>
        <p class="home-step-desc">One method call, a plain answer back. No client objects, no configuration ceremony, no response envelope to unwrap.</p>
        <a class="home-step-link" href="{% link _core_features/chat.md %}">Chat guide</a>
      </div>
      <div class="home-step-code home-code-grid home-code-grid--bare" markdown="1">

```ruby
RubyLLM.chat.ask "What's the best way to learn Ruby?"
```
{: .home-code-card }

</div>
    </div>

    <div class="home-step">
      <div class="home-step-text">
        <h3 class="home-step-title">Attach anything</h3>
        <p class="home-step-desc">Pass a file with <code>with:</code> and RubyLLM works out types, encoding, and provider formats. Images, audio, video, PDFs, even code.</p>
        <a class="home-step-link" href="{% link _core_features/attachments.md %}">Attachments guide</a>
      </div>
      <div class="home-step-code home-code-grid home-code-grid--bare" markdown="1">

```ruby
chat = RubyLLM.chat
chat.ask "What's in this image?", with: "ruby_conf.jpg"
chat.ask "Describe this meeting", with: "meeting.wav"
chat.ask "Summarize this document", with: "contract.pdf"
```
{: .home-code-card }

</div>
    </div>

    <div class="home-step">
      <div class="home-step-text">
        <h3 class="home-step-title">Stream responses</h3>
        <p class="home-step-desc">Add a block and chunks arrive as the model generates them. The same block drives a terminal script or a Turbo Stream.</p>
        <a class="home-step-link" href="{% link _core_features/streaming.md %}">Streaming guide</a>
      </div>
      <div class="home-step-code home-code-grid home-code-grid--bare" markdown="1">

```ruby
chat.ask "Tell me a story about Ruby" do |chunk|
  print chunk.content
end
```
{: .home-code-card }

</div>
    </div>

    <div class="home-step">
      <div class="home-step-text">
        <h3 class="home-step-title">Give the model tools</h3>
        <p class="home-step-desc">A tool is a plain Ruby class: describe it, implement <code>execute</code>, and the model calls your code when it needs to. The agentic loop is handled for you.</p>
        <a class="home-step-link" href="{% link _core_features/tools.md %}">Tools guide</a>
      </div>
      <div class="home-step-code home-code-grid home-code-grid--bare" markdown="1">

```ruby
class Weather < RubyLLM::Tool
  description "Get current weather"

  def execute(latitude:, longitude:)
    url = "https://api.open-meteo.com/v1/forecast?latitude=#{latitude}&longitude=#{longitude}&current=temperature_2m,wind_speed_10m"
    JSON.parse(Faraday.get(url).body)
  end
end

chat.with_tools(Weather).ask "What's the weather in Berlin?"
```
{: .home-code-card }

</div>
    </div>

    <div class="home-step">
      <div class="home-step-text">
        <h3 class="home-step-title">Get structured output</h3>
        <p class="home-step-desc">Declare the shape as a Ruby schema and responses come back as validated data, not prose you have to parse.</p>
        <a class="home-step-link" href="{% link _core_features/structured-output.md %}">Structured output guide</a>
      </div>
      <div class="home-step-code home-code-grid home-code-grid--bare" markdown="1">

```ruby
class ProductSchema < Schematist::Schema
  string :name
  number :price
  array :features do
    string
  end
end

response = chat.with_schema(ProductSchema).ask "Analyze this product", with: "product.txt"
```
{: .home-code-card }

</div>
    </div>

    <div class="home-step">
      <div class="home-step-text">
        <h3 class="home-step-title">Compose agents</h3>
        <p class="home-step-desc">Bundle model, instructions, and tools into a class you can instantiate, test, and reuse anywhere in your app.</p>
        <a class="home-step-link" href="{% link _advanced/agents.md %}">Agents guide</a>
      </div>
      <div class="home-step-code home-code-grid home-code-grid--bare" markdown="1">

```ruby
class WeatherAssistant < RubyLLM::Agent
  model "gpt-5-nano"
  instructions "Be concise and always use tools for weather."
  tools Weather
end

WeatherAssistant.new.ask "What's the weather in Berlin?"
```
{: .home-code-card }

</div>
    </div>
  </div>
</section>

<section id="complete" class="home-section home-band home-complete-section">
  <div class="home-section-inner">
    <h2 class="home-heading">Everything you'd expect from a complete framework</h2>
    <p class="home-lead">
      The capabilities Rubyists asked for, built in and documented.
    </p>
  </div>

  <div class="home-code-grid home-code-grid--columns" markdown="1">

```ruby
class IssueRefund < RubyLLM::Tool
  description "Issues a refund for an order"
  requires_approval

  def execute(order_id:) = Refunds.issue!(order_id)
end
```
{: .home-code-card data-title="Require human approval" data-href="{% link _core_features/tool-execution.md %}#requiring-approval" data-doc-title="Requiring Approval" }

```ruby
chats = documents.map do |doc|
  RubyLLM.chat(model: "claude-haiku-4-5")
    .with_instructions("Summarize in one paragraph.")
    .ask_later(doc.text)
end

batch = RubyLLM.batch(chats)
```
{: .home-code-card data-title="Cut costs with batches" data-href="{% link _advanced/batches.md %}" data-doc-title="Batches" }

```ruby
chat = RubyLLM.chat.with_caching
chat.with_instructions "You are a careful code reviewer."
chat.ask "Review this diff", with: "large_diff.patch"
```
{: .home-code-card data-title="Cache repeated prompts" data-href="{% link _core_features/prompt-caching.md %}" data-doc-title="Prompt Caching" }

```ruby
response = RubyLLM.chat
  .with_server_tools(:web_search)
  .ask "What's the latest stable Ruby? Cite sources."

response.citations
```
{: .home-code-card data-title="Search the web with citations" data-href="{% link _core_features/server-tools.md %}" data-doc-title="Server Tools" }

```ruby
documents = ["Ruby is expressive", "Python uses indentation"]
embeddings = RubyLLM.embed(documents)
ranked = RubyLLM.rerank("Ruby language", documents, model: "rerank-v3.5")
```
{: .home-code-card data-title="Build RAG and retrieval pipelines" data-href="{% link _advanced/rag.md %}" data-doc-title="RAG" }

```ruby
response = chat.ask "Explain embeddings"
response.tokens.output
response.cost.total
```
{: .home-code-card data-title="Track usage and costs" data-href="{% link _core_features/cost-and-usage-tracking.md %}" data-doc-title="Cost and Usage Tracking" }

```ruby
transcript = RubyLLM.transcribe "meeting.wav"
RubyLLM.speak(transcript.text).save "summary.mp3"
```
{: .home-code-card data-title="Understand and generate speech" data-href="{% link _core_features/text-to-speech.md %}" data-doc-title="Text to speech" }

```ruby
document = RubyLLM.ocr "scanned-contract.pdf"
puts document.markdown
```
{: .home-code-card data-title="Turn documents into Markdown" data-href="{% link _core_features/ocr.md %}" data-doc-title="Document OCR" }

```ruby
RubyLLM.paint "a sunset over mountains in watercolor style"
RubyLLM.animate "a paper boat sailing down a rainy gutter"
```
{: .home-code-card data-title="Generate images and video" data-href="{% link _core_features/video-generation.md %}" data-doc-title="Video generation" }

```ruby
RubyLLM.moderate("Some user-generated content").flagged?
```
{: .home-code-card data-title="Moderate user content" data-href="{% link _core_features/moderation.md %}" data-doc-title="Moderation" }

  </div>

  <div class="home-code-cta">
    <p>Then take it to production with
      <a href="{% link _advanced/agentic-workflows.md %}">agentic workflows</a>,
      <a href="{% link _advanced/durable-agents.md %}">durable agents</a>,
      <a href="{% link _advanced/memory.md %}">memory</a>,
      <a href="{% link _reference/ecosystem.md %}#rubyllmmcp">MCP</a>,
      <a href="{% link _getting_started/configuration-connection.md %}#contexts-isolated-configurations">multi-tenant contexts</a>,
      <a href="{% link _reference/ecosystem.md %}#rubyllminstrumentation">instrumentation</a>,
      <a href="{% link _reference/ecosystem.md %}#rubyllmmonitoring">monitoring</a>, and
      <a href="{% link _advanced/error-handling.md %}">predictable error handling</a>.
    </p>
    <div class="home-code-cta-actions">
      <a class="home-button home-button--solid home-button--guides" href="{% link _getting_started/getting-started.md %}">Build your first feature</a>
    </div>
  </div>
</section>

<section id="rails-integration" class="home-section home-rails-section">
  <div class="home-section-inner">
    <h2 class="home-heading">Feels at home in Rails</h2>
    <p class="home-lead">
      Persist complete conversations with Active Record, stream through Hotwire, and generate a working chat UI without introducing a second application architecture. Watch a complete AI chat go up in two minutes.
    </p>

    <div class="home-demo-frame home-rails-demo-frame" data-demo-video>
      <pre class="home-demo-terminal" aria-hidden="true"><code><span class="term-green">$</span> bundle add ruby_llm
<span class="term-green">$</span> bin/rails generate ruby_llm:install
<span class="term-green">$</span> bin/rails db:migrate
<span class="term-green">$</span> bin/rails generate ruby_llm:chat_ui

<span class="term-green">create</span>  app/models/chat.rb
<span class="term-green">create</span>  app/models/message.rb
<span class="term-green">create</span>  app/controllers/chats_controller.rb
<span class="term-green">create</span>  app/views/chats/show.html.erb
<span class="term-green">create</span>  app/jobs/chat_response_job.rb

<span class="term-green">$</span> bin/rails server
=> Booting Puma
=> Rails application starting on http://localhost:3000
~ <span class="term-cursor"></span></code></pre>
      <video class="home-demo-video" preload="metadata" playsinline>
        <source src="https://github.com/user-attachments/assets/65422091-9338-47da-a303-92b918bd1345" type="video/mp4">
      </video>
      <button class="home-play-button" type="button" aria-label="Play the two-minute RubyLLM Rails demo">
        <span aria-hidden="true"></span>
      </button>
      <img class="home-demo-avatar" src="{{ '/assets/images/founder/carmine.jpg' | relative_url }}" alt="" aria-hidden="true">
    </div>
  </div>

  <div class="home-code-grid home-code-grid--columns home-rails-code-grid" markdown="1">

```ruby
chat = Chat.create! model: "claude-opus-4-7"
chat.ask "What's in this file?", with: "report.pdf"
```
{: .home-code-card data-title="Persist chats with Active Record" data-href="{% link _advanced/rails-persistence.md %}#two-application-models" data-doc-title="Core Models and acts_as Methods" }

```sh
bin/rails generate ruby_llm:agent Support
bin/rails generate ruby_llm:tool Weather
bin/rails generate ruby_llm:schema Product
```
{: .home-code-card data-title="Generate agents, tools, and schemas" data-href="{% link _advanced/rails-generators.md %}#rails-generators-for-agents-tools-and-schemas" data-doc-title="Rails Generators for Agents, Tools, and Schemas" }

  </div>

  <div class="home-code-cta">
    <p>RubyLLM follows Rails conventions with
      <a href="{% link _advanced/rails-generators.md %}#conventional-directory-structure">conventional directory structures</a>,
      <a href="{% link _advanced/rails-generators.md %}#setting-up-activestorage">Active Storage attachments</a>,
      <a href="{% link _advanced/rails-streaming.md %}#streaming-responses-with-hotwireturbo">Hotwire and Turbo streaming</a>,
      <a href="{% link _advanced/agents.md %}#prompt-management-and-conventions">ERB prompt templates</a>, and
      <a href="{% link _advanced/durable-agents.md %}">durable execution across jobs and deploys</a>.
    </p>
    <div class="home-code-cta-actions">
      <a class="home-button home-button--solid home-button--rails" href="{% link _advanced/rails.md %}">Read the Rails guide</a>
    </div>
  </div>
</section>

<section class="home-section home-band home-companies-section">
  <div class="home-section-inner">
    <h2 class="home-heading">Built with RubyLLM</h2>
    <p class="home-lead">
      From independent products to established Rails teams, RubyLLM is already shipping in production.
    </p>

    <div class="home-company-logos" aria-label="Companies using RubyLLM">
      {% for company in site.data.company_logos_featured %}
        {% if company.mark %}
        <div class="home-company-logo home-company-logo--layered" data-company="{{ company.name | slugify }}">
          <img class="logo-layer-color" src="{{ company.mark | relative_url }}" alt="" aria-hidden="true">
          <img class="logo-layer-text" src="{{ company.text | relative_url }}" alt="{{ company.name }}">
        </div>
        {% elsif company.light and company.dark %}
        {% assign company_logo_light_external = false %}
        {% if company.light contains '://' or company.light contains 'data:' %}
          {% assign company_logo_light_external = true %}
        {% endif %}
        {% assign company_logo_dark_external = false %}
        {% if company.dark contains '://' or company.dark contains 'data:' %}
          {% assign company_logo_dark_external = true %}
        {% endif %}
        <div class="home-company-logo home-company-logo--theme-swap" data-company="{{ company.name | slugify }}">
          <img class="logo-light" src="{% if company_logo_light_external %}{{ company.light }}{% else %}{{ company.light | relative_url }}{% endif %}" alt="{{ company.name }}">
          <img class="logo-dark" src="{% if company_logo_dark_external %}{{ company.dark }}{% else %}{{ company.dark | relative_url }}{% endif %}" alt="{{ company.name }}">
        </div>
        {% else %}
        <div class="home-company-logo" data-company="{{ company.name | slugify }}">
          <img src="{{ company.src | relative_url }}" alt="{{ company.name }}">
        </div>
        {% endif %}
      {% endfor %}
    </div>

    <p class="home-small-note">
      Using RubyLLM?
      <a href="https://tally.so/r/3Na02p" target="_blank" rel="noreferrer">Get featured</a>
      or
      <a href="https://github.com/sponsors/crmne" target="_blank" rel="noreferrer">sponsor us</a>
    </p>
  </div>
</section>

<section class="home-section home-love-section" data-love-carousel>
  <div class="home-section-inner">
    <h2 class="home-heading">Why Rubyists choose RubyLLM</h2>
  </div>

  <div class="home-love-stage">
    <div class="home-love-grid">
    <article class="home-love-card" data-love-card>
      <header><img src="{{ '/assets/images/home/testimonials/people/jorge-manrubia.webp' | relative_url }}" alt="Jorge Manrubia"><strong>Jorge Manrubia</strong><small>Principal Programmer, 37signals</small></header>
      <p>We are using OpenAI API using the fantastic RubyLLM gem from @paolino.</p>
    </article>
    <article class="home-love-card" data-love-card>
      <header><img src="{{ '/assets/images/home/testimonials/people/nick-warwick.webp' | relative_url }}" alt="Nick Warwick"><strong>Nick Warwick</strong><small>Founding Engineer, Nodal Networks</small></header>
      <p>Our Langgraph agent was failing. I took a gamble and rebuilt it using RubyLLM. Not only was it far simpler, it performed better.</p>
    </article>
    <article class="home-love-card" data-love-card>
      <header><img src="{{ '/assets/images/home/testimonials/people/brendan-samek.webp' | relative_url }}" alt="Brendan Samek"><strong>Brendan Samek</strong><small>Founding Software Engineer, Build Canada</small></header>
      <p>It feels natural. At Yuma, serving over 100,000 end users, our unified AI interface had accumulated so much cruft. RubyLLM is so much nicer than all of that.</p>
    </article>
    <article class="home-love-card" data-love-card>
      <header><img src="{{ '/assets/images/home/testimonials/people/aaron-snyder.webp' | relative_url }}" alt="Aaron Snyder"><strong>Aaron Snyder</strong><small>CTO / Co-founder, Corepilot</small></header>
      <p>We got our proof of concept up in one day and the first beta in about a week. Really impressive.</p>
    </article>
    <article class="home-love-card" data-love-card>
      <header><img src="{{ '/assets/images/home/testimonials/people/joe-leo.webp' | relative_url }}" alt="Joe Leo"><strong>Joe Leo</strong><small>Founder/CEO, Def Method</small></header>
      <p>Most tools add layers. This one removes them. It keeps the mental load low.</p>
    </article>
    <article class="home-love-card" data-love-card>
      <header><img src="{{ '/assets/images/home/testimonials/people/cole-robertson.webp' | relative_url }}" alt="Cole Robertson"><strong>Cole Robertson</strong><small>Co-founder and CTO, dScribe AI</small></header>
      <p>The speed of development and the closest thing to the AI SDK in JavaScript land. Easiest Rails integration.</p>
    </article>
    <article class="home-love-card" data-love-card>
      <header><img src="{{ '/assets/images/home/testimonials/people/philippe-lehoux.webp' | relative_url }}" alt="Philippe Lehoux"><strong>Philippe Lehoux</strong><small>CEO, Missive</small></header>
      <p>Multi-provider support. Agentic loop support. Can we sponsor?</p>
    </article>
    <article class="home-love-card" data-love-card>
      <header><img src="{{ '/assets/images/home/testimonials/people/hamid-siddiqui.webp' | relative_url }}" alt="Hamid Siddiqui"><strong>Hamid Siddiqui</strong><small>Founder, ReelMoney</small></header>
      <p>I replaced my internal provider implementation with RubyLLM and it just worked nicely. Deleted a lot of code.</p>
    </article>
    <article class="home-love-card" data-love-card>
      <header><img src="{{ '/assets/images/home/testimonials/people/marc-kohlbrugge.webp' | relative_url }}" alt="Marc Köhlbrugge"><strong>Marc Köhlbrugge</strong><small>Founder/CEO, Startup Jobs</small></header>
      <p>Ruby-esque DSL and the right level of abstraction: composable, flexible on architecture, opinionated on lower-level implementation.</p>
    </article>
    <article class="home-love-card" data-love-card hidden>
      <header><img src="{{ '/assets/images/home/testimonials/people/kieran-klaassen.webp' | relative_url }}" alt="Kieran Klaassen"><strong>Kieran Klaassen</strong><small>Founder, Cora</small></header>
      <p>Love deleting code when adding a library, and love the thought that goes into the gem.</p>
    </article>
    <article class="home-love-card" data-love-card hidden>
      <header><img src="{{ '/assets/images/home/testimonials/people/elvinas-predkelis.webp' | relative_url }}" alt="Elvinas Predkelis"><strong>Elvinas Predkelis</strong><small>CEO, Primevise</small></header>
      <p>RubyLLM is pretty much the devise of this generation. Adding it to any application is pretty much a no-brainer.</p>
    </article>
    <article class="home-love-card" data-love-card hidden>
      <header><img src="{{ '/assets/images/home/testimonials/people/axel-grubba.webp' | relative_url }}" alt="Axel Grubba"><strong>Axel Grubba</strong><small>Founder, Crevio</small></header>
      <p>Love how Ruby-like it feels. The DSL is incredibly intuitive and follows all the conventions I would expect.</p>
    </article>
    <article class="home-love-card" data-love-card hidden>
      <header><img src="{{ '/assets/images/home/testimonials/people/luis-ezcurdia.webp' | relative_url }}" alt="Luis Ezcurdia"><strong>Luis Ezcurdia</strong><small>Software Engineer</small></header>
      <p>RubyLLM is awesome, easy and intuitive. You should try it, even if you don’t work with Ruby.</p>
    </article>
    <article class="home-love-card" data-love-card hidden>
      <header><img src="{{ '/assets/images/home/testimonials/people/chris-sonnier.webp' | relative_url }}" alt="Chris Sonnier"><strong>Chris Sonnier</strong><small>Ruby/Rails Engineer</small></header>
      <p>If you can find a better Ruby AI library than RubyLLM, I will only write JavaScript for the rest of the year!</p>
    </article>
    <article class="home-love-card" data-love-card hidden>
      <header><img src="{{ '/assets/images/home/testimonials/people/mauro-eldritch.webp' | relative_url }}" alt="Mauro Eldritch"><strong>Mauro Eldritch</strong><small>Founder, BCA LTD</small></header>
      <p>We built our own quick and dirty wrapper, then your project came up and rocked it.</p>
    </article>
    <article class="home-love-card" data-love-card hidden>
      <header><img src="{{ '/assets/images/home/testimonials/people/ruslan-leteyski.webp' | relative_url }}" alt="Ruslan Leteyski"><strong>Ruslan Leteyski</strong><small>CEO, Zipchat</small></header>
      <p>Implementation-agnostic access to models helps us simplify our flow and experiment with agentic systems.</p>
    </article>
    <article class="home-love-card" data-love-card hidden>
      <header><img src="{{ '/assets/images/home/testimonials/people/jonathan-satovsky.webp' | relative_url }}" alt="Jonathan Satovsky"><strong>Jonathan Satovsky</strong><small>CEO, FinDash</small></header>
      <p>When a tool removes noise instead of adding it, you get to stay focused on the real work.</p>
    </article>
    <article class="home-love-card" data-love-card hidden>
      <header><img src="{{ '/assets/images/home/testimonials/people/rich-chetwynd.webp' | relative_url }}" alt="Rich Chetwynd"><strong>Rich Chetwynd</strong><small>Generalist, Bunny Inc</small></header>
      <p>Super easy way to start adding magic to our app. Love the speed of improvements.</p>
    </article>
    <article class="home-love-card" data-love-card hidden>
      <header><img src="{{ '/assets/images/home/testimonials/people/ale-solano.webp' | relative_url }}" alt="Ale Solano"><strong>Ale Solano</strong><small>Software Engineer, OpenRegulatory</small></header>
      <p>Just having a framework to structure all our LLM processes is gigantic value. Tool integration works like a charm.</p>
    </article>
    <article class="home-love-card" data-love-card hidden>
      <header><img src="{{ '/assets/images/home/testimonials/people/eric-wright.webp' | relative_url }}" alt="Eric Wright"><strong>Eric Wright</strong><small>Chief Content Officer, GTM Delta</small></header>
      <p>It just works. I do not want to keep dealing with wrappers and fast-moving provider changes.</p>
    </article>
    <article class="home-love-card" data-love-card hidden>
      <header><img src="{{ '/assets/images/home/testimonials/people/hadrien-blanc.webp' | relative_url }}" alt="Hadrien Blanc"><strong>Hadrien Blanc</strong><small>Freelancer, Hadrien Blanc Innovation</small></header>
      <p>I delivered a lot of value to my customers because of your work.</p>
    </article>
    <article class="home-love-card" data-love-card hidden>
      <header><img src="{{ '/assets/images/home/testimonials/people/dewayne-vanhoozer.webp' | relative_url }}" alt="Dewayne VanHoozer"><strong>Dewayne VanHoozer</strong><small>The MadBomber, MadBomber Software</small></header>
      <p>Letting someone else manage the fast-moving infrastructure of the LLM API landscape allowed me to focus on applications.</p>
    </article>
    <article class="home-love-card" data-love-card hidden>
      <header><img src="{{ '/assets/images/home/testimonials/people/john-desilva.webp' | relative_url }}" alt="John DeSilva"><strong>John DeSilva</strong><small>Chief Architect, Revela</small></header>
      <p>Really solid overall, well thought out, and seamless across Rails model-backed chats and one-off chats.</p>
    </article>
    <article class="home-love-card" data-love-card hidden>
      <header><img src="{{ '/assets/images/home/testimonials/people/angel-mendez.webp' | relative_url }}" alt="Angel Mendez"><strong>Angel Mendez</strong><small>CEO, Yato</small></header>
      <p>My clients and my clients&#39; clients are very happy because we can iterate and improve our system quickly.</p>
    </article>
    <article class="home-love-card" data-love-card hidden>
      <header><img src="{{ '/assets/images/home/testimonials/people/nina-revko.webp' | relative_url }}" alt="Nina Revko"><strong>Nina Revko</strong><small>Senior Software Engineer, Instrumentl</small></header>
      <p>RubyLLM made the future of Ruby and AI feel easier, more accessible, and completely within reach.</p>
    </article>
    <article class="home-love-card" data-love-card hidden>
      <header><img src="{{ '/assets/images/home/testimonials/people/daniel-friis.webp' | relative_url }}" alt="Daniel Friis"><strong>Daniel Friis</strong><small>Creator, Schematist</small></header>
      <p>Foundational tooling for working with AI in Ruby and Rails applications.</p>
    </article>
    <article class="home-love-card" data-love-card hidden>
      <header><img src="{{ '/assets/images/home/testimonials/people/giovapanasiti.webp' | relative_url }}" alt="Giovanni Panasiti"><strong>Giovanni Panasiti</strong><small>Co-founder, Consultala</small></header>
      <p>I’m kinda fitting RubyLLM into all of my projects.</p>
    </article>
    </div>
    <nav class="home-love-controls" aria-label="Wall of Love quotes">
      <button class="home-love-nav home-love-nav--prev" type="button" data-love-prev aria-label="Previous quotes"><span aria-hidden="true"></span></button>
      <button class="home-love-nav home-love-nav--next" type="button" data-love-next aria-label="Next quotes"><span aria-hidden="true"></span></button>
    </nav>
  </div>

  <p class="home-small-note">
    Using RubyLLM?
    <a href="https://tally.so/r/3Na02p" target="_blank" rel="noreferrer">Share your story!</a>
    Takes 5 minutes.
  </p>
</section>

<section class="home-section home-band home-ready-section">
  <div class="home-section-inner">
    <h2 class="home-heading">Start with one line of Ruby</h2>

    <div class="home-code-grid home-code-grid--bare home-ready-code" markdown="1">

```ruby
RubyLLM.chat.ask "Hello, Ruby!"
```
{: .home-code-card }

</div>

    <div class="home-ready-actions">
      <a class="home-button home-button--solid home-button--gem" href="{{ '/getting-started/' | relative_url }}#installation">Install the gem</a>
      <a class="VPButton medium alt home-hero-metric-button" href="https://github.com/crmne/ruby_llm" aria-label="View RubyLLM source on GitHub" target="_blank" rel="noreferrer noopener">
        <span class="vpi-social-github" aria-hidden="true"></span>
        <span>View source</span>
      </a>
    </div>
  </div>
</section>

<footer class="home-footer">
  <div class="home-footer-inner">
    <p class="home-footer-credit">
      Brought to you by <a href="https://paolino.me" target="_blank" rel="noreferrer">Carmine Paolino</a><br>
      maker of
      <a class="home-footer-chat-with-work" href="https://chatwithwork.com" target="_blank" rel="noreferrer" aria-label="Chat with Work">
        <img class="home-footer-chat-with-work-logo-light" src="https://chatwithwork.com/logotype.svg" alt="Chat with Work">
        <img class="home-footer-chat-with-work-logo-dark" src="https://chatwithwork.com/logotype-dark.svg" alt="Chat with Work">
      </a>
      <small>Fully private work AI</small>
    </p>
    <p class="home-footer-credit">Docs built with <a href="https://jekyll-vitepress.dev">Jekyll Vitepress</a></p>
  </div>
</footer>
