# Batch Request Feature

The batch request feature allows you to generate API request payloads without actually making API calls. This is useful for:

1. **Batch Processing**: Generate multiple request payloads and send them to provider batch endpoints
2. **Testing**: Verify request payload structure without making API calls
3. **Debugging**: Inspect the exact payload that would be sent to the provider

## Basic Usage

```ruby
# Enable batch request mode
chat = RubyLLM.chat.for_batch_request
chat.add_message(role: :user, content: "What's 2 + 2?")

# Returns the request payload instead of making an API call
payload = chat.complete
# => {:custom_id=>"...", :method=>"POST", :url=>"/v1/chat/completions", :body=>{...}}
```

## Generating Multiple Batch Requests

```ruby
requests = []

3.times do |i|
  chat = RubyLLM.chat.for_batch_request
  chat.add_message(role: :user, content: "Question #{i + 1}")
  
  requests << chat.complete
end

# Now you have an array of request payloads
# You can format them as JSONL and send to provider batch endpoints
```

## Provider Support

Currently, only OpenAI supports batch requests. Other providers will raise `NotImplementedError`:

```ruby
# OpenAI (supported)
chat = RubyLLM.chat(provider: :openai).for_batch_request
chat.add_message(role: :user, content: "Hello")
payload = chat.complete
# => {
#      :custom_id=>"request-abc123",
#      :method=>"POST",
#      :url=>"/v1/chat/completions",
#      :body=>{:model=>"gpt-4", :messages=>[...]}
#    }

# Other providers (not supported)
chat = RubyLLM.chat(provider: :anthropic).for_batch_request
chat.add_message(role: :user, content: "Hello")
chat.complete  # Raises NotImplementedError
```

## Usage with Other Methods

The `for_batch_request` method chains with other configuration methods:

```ruby
chat = RubyLLM.chat
  .with_model('gpt-4')
  .with_temperature(0.7)
  .with_tool(MyTool)
  .for_batch_request

chat.ask("Process this")
payload = chat.complete  # Returns batch request payload
```

## Notes

- Streaming is not supported when in batch request mode
- The batch request payload includes all configured parameters (tools, schema, temperature, etc.)
- No messages are added to the chat history when generating batch request payloads
- Providers must explicitly implement `render_payload_for_batch_request` to support this feature

## Future Enhancements

The remaining steps for full batch processing support (to be implemented by users):

2. Combine multiple request payloads (typically in JSONL format)
3. Submit to provider's batch endpoint
4. Poll for batch completion status
5. Process batch results

These steps are provider-specific and can be implemented based on your needs.