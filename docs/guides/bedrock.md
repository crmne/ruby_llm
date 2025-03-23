---
layout: default
title: Using AWS Bedrock
parent: Guides
nav_order: 10
permalink: /guides/bedrock
---

# Using AWS Bedrock

RubyLLM supports AWS Bedrock as a model provider, giving you access to Claude models (and eventually others) through your AWS infrastructure. This guide explains how to configure and use AWS Bedrock with RubyLLM.

## Configuration

To use AWS Bedrock, you'll need to configure RubyLLM with your AWS credentials. There are several ways to do this:

### Using AWS STS (Security Token Service)

If you're using temporary credentials through AWS STS, you can configure RubyLLM like this:

```ruby
require 'aws-sdk-core'
require 'ruby_llm'

# Get credentials from STS
sts_client = Aws::STS::Client.new
creds = sts_client.get_session_token

RubyLLM.configure do |config|
  config.bedrock_api_key = creds.credentials.access_key_id
  config.bedrock_secret_key = creds.credentials.secret_access_key
  config.bedrock_session_token = creds.credentials.session_token
  config.bedrock_region = 'us-west-2'  # Specify your desired AWS region
end
```

### Using Environment Variables

You can also configure AWS credentials through environment variables:

```bash
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_SESSION_TOKEN=your_session_token  # If using temporary credentials
export AWS_REGION=us-west-2
```
```ruby
RubyLLM.configure do |config|
  config.bedrock_api_key = ENV['AWS_ACCESS_KEY_ID']
  config.bedrock_secret_key = ENV['AWS_SECRET_ACCESS_KEY']
  config.bedrock_session_token = ENV['AWS_SESSION_TOKEN'] # If using temporary credentials
  config.bedrock_region = ENV['AWS_REGION']
end
```

## Using Bedrock Models

There are two ways to specify that you want to use Bedrock as your provider:

### Method 1: Specify Provider at Initialization

```ruby
chat = RubyLLM.chat(
  model: 'claude-3-5-sonnet',
  provider: :bedrock
)

response = chat.ask('Hello, how are you?')
puts response.content
```

### Method 2: Use the Provider Chain Method

```ruby
chat = RubyLLM.chat(
  model: 'claude-3-5-sonnet'
).with_provider(:bedrock)

response = chat.ask('Hello, how are you?')
puts response.content
```

## Available Models

AWS Bedrock provides access to various models. You can list available Bedrock models using:

```ruby
bedrock_models = RubyLLM.models.by_provider('bedrock')
bedrock_models.each do |model|
  puts "#{model.id} (#{model.display_name})"
end
```

## Best Practices

When using AWS Bedrock with RubyLLM:

1. **Credential Management** - Always follow AWS best practices for credential management
2. **Region Selection** - Choose the AWS region closest to your application for best performance
3. **Error Handling** - Handle AWS-specific errors appropriately in your application
4. **Cost Monitoring** - Monitor your AWS Bedrock usage through AWS Console or CloudWatch

## Troubleshooting

Common issues and solutions:

- **Authentication Errors**: Ensure your AWS credentials are properly configured and have the necessary permissions for Bedrock
- **Region Issues**: Verify that Bedrock is available in your selected AWS region
- **Token Expiration**: When using temporary credentials, make sure to refresh them before they expire

For more information about AWS Bedrock, visit the [AWS Bedrock documentation](https://docs.aws.amazon.com/bedrock). 
