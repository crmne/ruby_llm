---
layout: default
title: API Reference
nav_order: 0
description: RDoc documentation for every public RubyLLM class and method
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

The [API reference]({{ '/api/' | relative_url }}) opens on the RubyLLM module, with the framework's entry points and examples. Each class and method documents its arguments, return value, and behavior.

| Build with | Reference |
| --- | --- |
| Conversations and structured responses | [Chat]({{ '/api/RubyLLM/Chat.html' | relative_url }}), [Message]({{ '/api/RubyLLM/Message.html' | relative_url }}) |
| Tools and agents | [Tool]({{ '/api/RubyLLM/Tool.html' | relative_url }}), [Agent]({{ '/api/RubyLLM/Agent.html' | relative_url }}) |
| Images, video, and speech | [Image]({{ '/api/RubyLLM/Image.html' | relative_url }}), [Video]({{ '/api/RubyLLM/Video.html' | relative_url }}), [Speech]({{ '/api/RubyLLM/Speech.html' | relative_url }}) |
| Transcription, OCR, and moderation | [Transcription]({{ '/api/RubyLLM/Transcription.html' | relative_url }}), [OCR]({{ '/api/RubyLLM/OCR.html' | relative_url }}), [Moderation]({{ '/api/RubyLLM/Moderation.html' | relative_url }}) |
| Search and retrieval | [Embedding]({{ '/api/RubyLLM/Embedding.html' | relative_url }}), [Rerank]({{ '/api/RubyLLM/Rerank.html' | relative_url }}) |
| Rails records | [ActiveRecord::ActsAs]({{ '/api/RubyLLM/ActiveRecord/ActsAs.html' | relative_url }}) |
| Models and configuration | [Models]({{ '/api/RubyLLM/Models.html' | relative_url }}), [Configuration]({{ '/api/RubyLLM/Configuration.html' | relative_url }}), [Context]({{ '/api/RubyLLM/Context.html' | relative_url }}) |
| Usage and background processing | [Tokens]({{ '/api/RubyLLM/Tokens.html' | relative_url }}), [Cost]({{ '/api/RubyLLM/Cost.html' | relative_url }}), [Batch]({{ '/api/RubyLLM/Batch.html' | relative_url }}) |

For Markdown, start with [RubyLLM.md]({{ '/api/RubyLLM.md' | relative_url }}) or the [class index]({{ '/api/index.md' | relative_url }}). Every HTML class page has a matching `.md` page.

The reference is generated from source comments with RDoc. Build it locally with `bundle exec rake rdoc`.
