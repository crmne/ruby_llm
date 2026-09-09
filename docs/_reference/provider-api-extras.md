---
layout: coverage
title: Additional Provider APIs
description: Explore provider-specific APIs and service boundaries separately from RubyLLM's shared feature comparison.
provider_coverage: true
nav_exclude: true
llms: false
---

<article class="provider-coverage">
<header class="coverage-header">
  <p class="coverage-eyebrow">RubyLLM {{ site.data.provider_coverage.version }}{% if site.data.provider_coverage.working_tree %} · Working tree{% endif %}</p>
  <h1>{{ page.title }}</h1>
  <p>These additional rows record provider-specific operations, related endpoints, and service boundaries. They are separate from the shared features and do not contribute to the coverage chart.</p>
  <p class="coverage-audit-date">Source audit: {{ site.data.provider_coverage.audited_on }}</p>
  <p><a href="{% link _reference/provider-coverage.md %}#coverage-method">How to read this audit</a> · <a href="{{ '/provider-coverage.json' | relative_url }}" download>Download all audit data</a></p>
</header>

{% include provider_coverage_matrix.html additional=true current=true %}
</article>
