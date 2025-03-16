# OpenRouter Integration

## Context
I'm hitting Anthropic rate limits constantly with my own usage, and several community members have requested OpenRouter integration. This would allow access to a wider range of models through a single API key while maintaining RubyLLM's unified interface.

## Benefits
- Single API key to access models across providers
- Potential cost savings through OpenRouter's pricing
- Simplified rate limit management
- Access to exclusive models not available through direct provider integrations
- Fallback capabilities when primary providers are at capacity

## Implementation Considerations
- OpenRouter largely follows OpenAI's API structure, so we can likely adapt our existing OpenAI provider implementation
- Need to handle model ID mapping/translation to keep the model selection experience consistent
- Should implement proper error handling for OpenRouter-specific cases
- Will need to update the Models registry to include OpenRouter-accessible models

## Scope
Initial implementation should focus on:
- Chat completion support (highest priority)
- Embeddings support
- Model listing
- Full streaming support
- Tool use
- Image generation through DALL-E can be a second phase.

## Progress

### Completed
- ✅ Set up initial OpenRouter provider module structure
- ✅ Implemented basic OpenRouter API integration
- ✅ Fixed tests to run without requiring API keys for all providers
- ✅ Added proper test structure for OpenRouter tests
- ✅ Configured environment variables for OpenRouter API key

### In Progress
- 🔄 Implement model discovery and capabilities for OpenRouter
- 🔄 Implement chat completion support
- 🔄 Implement streaming support
- 🔄 Implement tool use support

### Next Steps
- Register OpenRouter provider in the main RubyLLM module
- Implement proper error handling for OpenRouter-specific cases
- Test with complex conversations, tools, and streaming
- Add documentation for OpenRouter integration
- Create examples for using OpenRouter with RubyLLM

## Technical Approach
- Follow the existing provider pattern used for OpenAI and Anthropic
- Adapt the OpenAI provider implementation where possible since OpenRouter follows a similar API structure
- Ensure proper model ID mapping/translation to maintain consistent model selection experience
- Implement comprehensive tests for all OpenRouter functionality
- Document the OpenRouter integration in the README and API documentation