# next

* fetch contents from https://github.com/crmne/ruby_llm/issues/8
```
Context
I'm hitting Anthropic rate limits constantly with my own usage, and several community members have requested OpenRouter integration. This would allow access to a wider range of models through a single API key while maintaining RubyLLM's unified interface.

Benefits
Single API key to access models across providers
Potential cost savings through OpenRouter's pricing
Simplified rate limit management
Access to exclusive models not available through direct provider integrations
Fallback capabilities when primary providers are at capacity
Implementation Considerations
OpenRouter largely follows OpenAI's API structure, so we can likely adapt our existing OpenAI provider implementation
Need to handle model ID mapping/translation to keep the model selection experience consistent
Should implement proper error handling for OpenRouter-specific cases
Will need to update the Models registry to include OpenRouter-accessible models
Scope
Initial implementation should focus on:

Chat completion support (highest priority)
Embeddings support
Model listing
Full streaming support
Tool use
Image generation through DALL-E can be a second phase.

Next Steps
Research OpenRouter API documentation
Create a new Provider module for OpenRouter
Implement proper model discovery and capabilities
Test with complex conversations, tools, and streaming
```


* put that into our plan
* use RULES.md for guidance on technical approach
* fork this and PR