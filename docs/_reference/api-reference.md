---
layout: default
title: API Reference
nav_order: 0
description: RDoc documentation for every public RubyLLM class and method
---

# {{ page.title }}
{: .no_toc }

The full RDoc documentation for every public class and method in this
version of RubyLLM.

[Browse the API docs]({{ '/api/' | relative_url }}){: .btn .btn-primary .fs-5 }
[Browse as Markdown]({{ '/api/index.md' | relative_url }}){: .btn .fs-5 }

These guides show you how to build things. The API reference tells you
exactly what each class and method does: signatures, return values, and
examples, in the style of Ruby's own documentation. Good entry points:

- [RubyLLM]({{ '/api/RubyLLM.html' | relative_url }}) ([Markdown]({{ '/api/RubyLLM.md' | relative_url }})), the module-level entry points
- [Chat]({{ '/api/RubyLLM/Chat.html' | relative_url }}) ([Markdown]({{ '/api/RubyLLM/Chat.md' | relative_url }})), conversations and the agentic loop
- [Tool]({{ '/api/RubyLLM/Tool.html' | relative_url }}) ([Markdown]({{ '/api/RubyLLM/Tool.md' | relative_url }})), giving models abilities
- [Agent]({{ '/api/RubyLLM/Agent.html' | relative_url }}) ([Markdown]({{ '/api/RubyLLM/Agent.md' | relative_url }})), reusable configured chats
- [ActiveRecord::ActsAs]({{ '/api/RubyLLM/ActiveRecord/ActsAs.html' | relative_url }}) ([Markdown]({{ '/api/RubyLLM/ActiveRecord/ActsAs.md' | relative_url }})), the Rails macros
- [Models]({{ '/api/RubyLLM/Models.html' | relative_url }}) ([Markdown]({{ '/api/RubyLLM/Models.md' | relative_url }})), the model registry
- [Configuration]({{ '/api/RubyLLM/Configuration.html' | relative_url }}) ([Markdown]({{ '/api/RubyLLM/Configuration.md' | relative_url }})), every setting

The API reference is generated from the source with RDoc. Build it locally
with `rake rdoc`.
