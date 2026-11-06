---
layout: default
title: Testing
nav_order: 16
description: Script what the model replies, so tests run your real chats, agents, and pages with no provider and no API key.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to script a model's replies in a test.
* How to test tools, streaming, cost, and a Stop button.
* What the stub runs for real, and what it replaces.

## Scripting Replies

Require `ruby_llm/test_helper` in your test helper, include `RubyLLM::TestHelper` the way you include `ActiveJob::TestHelper`, and say what the model replies:

```ruby
require "ruby_llm/test_helper"

class SupportAgentTest < ActiveSupport::TestCase
  include RubyLLM::TestHelper

  test "answers" do
    stub_replies "Hello there", cost: 0.01

    reply = SupportAgent.new.ask("Hi")

    assert_equal "Hello there", reply.content
    assert_equal 0.01, reply.cost.total
  end
end
```

In RSpec, add `config.include RubyLLM::TestHelper`. The stub ends with the test.

Replies come in the order you give them, and the last one repeats:

```ruby
stub_replies "First", "Second"
```

## Testing Tools

`tool_call` scripts a reply that calls a tool. Your tool really runs, and the next reply answers it:

```ruby
stub_replies tool_call(:weather, city: "Berlin"), "It is sunny."

reply = chat.with_tools(Weather).ask("Weather in Berlin?")

assert_equal "It is sunny.", reply.content
```

## Testing Streaming and Stop

A reply streams word by word to any block. `interval:` sets the seconds between words, so a test has time to cancel:

```ruby
stub_replies "A reply long enough to stop halfway through", interval: 0.1

visit chat_path(chat)
click_on "Stop"

assert_no_text "halfway through"
```

The stub works across threads, so a system test's server and its background jobs see it too.

## What the Stub Replaces

The stub answers in place of the provider, and everything else runs for real: the conversation loop, tools, persistence, the usage ledger, cost, cancellation, and broadcasting. It needs no API key, and it doesn't check the request, so it says nothing about how a real model answers. For that, use [evaluations]({% link _advanced/evaluations.md %}).

Anything that talks to a provider other than a chat, such as `RubyLLM.embed`, still needs a key.
