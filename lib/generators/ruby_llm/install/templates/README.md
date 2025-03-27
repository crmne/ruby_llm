# RubyLLM Rails Setup Complete!

Thanks for installing RubyLLM in your Rails application. Here's what was created:

## Models

- `Chat` - Stores chat sessions and their associated model ID
- `Message` - Stores individual messages in a chat
- `ToolCall` - Stores tool calls made by language models

## Next Steps

1. **Run migrations:**
   ```bash
   rails db:migrate
   ```

2. **Set your API keys** in `config/initializers/ruby_llm.rb` or using environment variables:
   ```ruby
   # config/initializers/ruby_llm.rb
   RubyLLM.configure do |config|
     config.openai_api_key = ENV["OPENAI_API_KEY"]
     config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"]
     # etc.
   end
   ```

3. **Start using RubyLLM in your code:**
   ```ruby
   # Create a new chat
   chat = Chat.create!(model_id: "gpt-4o-mini")
   
   # Ask a question
   response = chat.ask("What's the best Ruby web framework?")
   
   # Get chat history
   chat.messages
   ```

4. **For streaming responses** with ActionCable or Turbo:
   ```ruby
   chat.ask("Tell me about Ruby on Rails") do |chunk|
     Turbo::StreamsChannel.broadcast_append_to(
       chat, target: "response", partial: "messages/chunk", locals: { chunk: chunk }
     )
   end
   ```

## Advanced Usage

- Add more fields to your models as needed
- Customize the views to match your application design
- Create a controller for chat interactions

For more information, visit the [RubyLLM Documentation](https://github.com/crmne/ruby_llm)