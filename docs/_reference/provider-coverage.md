---
layout: coverage
title: Provider API Coverage
nav_order: 6
description: Check RubyLLM's current API support across seventeen providers, with implementation notes, sources, and remaining gaps.
provider_coverage: true
llms: false
---

{% assign coverage = site.data.provider_coverage %}
<article class="provider-coverage" data-coverage-url="{{ '/provider-coverage.json' | relative_url }}">
<header class="coverage-header">
  <p class="coverage-eyebrow">RubyLLM {{ coverage.version }}{% if coverage.working_tree %} · Working tree{% endif %}</p>
  <h1>{{ page.title }}</h1>
  <p>{{ page.description }}</p>
  <p class="coverage-audit-date">Source audit: {{ coverage.audited_on }} · {{ coverage.providers.size }} providers · {{ coverage.summary.feature_count }} shared feature rows</p>
  <p><a href="{% link _getting_started/whats-new-in-2-0.md %}">What's New in 2.0</a> · <a href="#coverage-method">How to read this audit</a> · <a href="{{ '/provider-coverage.json' | relative_url }}" download>Download the audit data</a> · <a href="{{ '/assets/images/provider-coverage.svg' | relative_url }}" download>Download the chart</a></p>
</header>

<h2 id="coverage-matrix-heading">Feature Matrix</h2>
<p>Solid red cells show built-in support. Lighter red cells with {} are usable through raw options. Red stripes show partial support. Outlined cells with a × mark missing integrations. Use “Missing” to highlight them. Select a cell for evidence, or switch to “Provider offers” to see the verified offerings.</p>
{% include provider_coverage_matrix.html current=true %}

<h2>Coverage Totals</h2>
{% include provider_coverage_summary.html current=true %}

<section id="coverage-method" class="coverage-prose">
<h2>How to Read This Audit</h2>
<p>This records current RubyLLM support against provider documentation checked on {{ coverage.audited_on }}. {% if coverage.working_tree %}The results include local changes based on <a href="https://github.com/crmne/ruby_llm/tree/{{ coverage.revision }}">{{ coverage.revision | slice: 0, 8 }}</a>; implementation links show that base revision.{% else %}The source is pinned to <a href="https://github.com/crmne/ruby_llm/tree/{{ coverage.revision }}">{{ coverage.revision | slice: 0, 8 }}</a>.{% endif %} Selected integrations have regression tests and fresh API recordings. Their cells include a separate Validation section with dates, models, specs and recordings. Built-in support and live access are separate: a documented implementation can work on a supported deployment even when that deployment was unavailable to this audit. Each cell records model, endpoint and validation limits. Other cells remain source and documentation findings.</p>
<dl class="coverage-definitions">
{% for entry in coverage.statuses %}<dt>{{ entry[1].label }}</dt><dd>{{ entry[1].description }}</dd>{% endfor %}
</dl>
<p>Deprecated APIs are marked with a dash and excluded from the missing-integration list. Their details retain the announced shutdown date; an API awaiting shutdown can still appear in “Provider offers”. Thinking controls refer to settings on a generation request, rather than changes to a hosted agent's configuration.</p>
<p>Realtime conversations and provider-stored conversation lifecycles are outside this release's scope. Those cells retain the provider's offering and explain the boundary, but do not count toward the chart or missing-integration list. Streaming speech generation and transcription remain included. Chat requests use the application's local history.</p>
<p>The shared rows cover conversation features, tools, caching, media, search, files, and batches. Additional API rows record other findings, including realtime, training, and provider-specific operations. They are not included in the chart. Unknown availability is kept separate from a confirmed absence. These rows differ in scope and sometimes overlap, so they should not be added into a percentage of an entire provider API.</p>
<p>“Not in this API” means the audited endpoint inventory does not document this operation. It does not describe every product the company sells. Azure Content Safety and Document Intelligence, Google Document AI, and AWS Data Automation and AgentCore are separate services outside this comparison. Each provider's notes specify its scope. Use “Needs verification” to find unresolved cells and read what remains uncertain.</p>
<p>Human approval, model fallbacks, agents, workflows, the usage ledger, and Rails persistence are RubyLLM features. They are described in <a href="{% link _getting_started/whats-new-in-2-0.md %}">What's New in 2.0</a> and are not counted as provider endpoints here. Cloud administration, deployment, billing, model training, and resource management have not been exhaustively audited.</p>
<p>Input modalities refer to chat attachments, with the supported API named in each cell. Transcription, OCR, and media generation are separate operations. Multiple tool calls means receiving several calls in one response; limiting parallel calls is a separate control. Prompt caching, explicit boundaries, and separately created cache resources are also distinct.</p>
<p>Context compaction includes provider controls that reduce the active context, such as summarization or a sliding window. Responses rows refer to the Responses protocol; the Perplexity Agent API is a separate row. Built-in support means RubyLLM exposes the operation on supported models and routes, with any limitations recorded in the cell. It does not promise every model, optional setting, or backend works. Selecting a supported protocol or passing options to a registered server-tool alias still counts as built-in support. “Raw options” means the operation requires a provider-shaped request without that integration.</p>
</section>

<section class="coverage-prose" aria-labelledby="coverage-gaps-heading">
<h2 id="coverage-gaps-heading">Remaining Gaps and Provider Limits</h2>
<p>The notes below identify remaining gaps, provider limits, and areas needing further validation.</p>
{% for provider in coverage.providers %}
<details class="coverage-provider-notes" id="coverage-notes-{{ provider.id }}">
<summary>{{ provider.name }}</summary>
{% if provider.notes %}<p>{{ provider.notes | escape }}</p>{% endif %}
<ul>{% for gap in provider.gaps %}<li>{{ gap.notes | escape }}{% for source_id in gap.sources %}{% assign source = coverage.sources[source_id] %} <a href="{{ source.url }}">{{ source.title | escape }}</a>.{% endfor %}</li>{% endfor %}</ul>
</details>
{% endfor %}
</section>
</article>
