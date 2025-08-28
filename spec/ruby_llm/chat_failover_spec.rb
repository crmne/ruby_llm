# frozen_string_literal: true

RSpec.describe RubyLLM::Chat do
  context 'with failover' do
    include_context 'with configured RubyLLM'

    it 'fails over to the next provider when the first one fails' do
      chat = RubyLLM.chat(provider: :anthropic, model: 'claude-3-7-sonnet')
      chat.with_failover({ provider: :bedrock, model: 'claude-3-7-sonnet' })

      chat.ask "#{MASSIVE_TEXT_FOR_RATE_LIMIT_TEST} What is the capital of France?"

      chat.ask 'What is the capital of Germany?'
      chat.ask 'What is the capital of Italy?'
      response = chat.ask 'What is the capital of England?'

      expect(response.content).to include('London')
    end

    it 'has a list of models to failover to' do
      chat = RubyLLM.chat(provider: :anthropic, model: 'claude-3-7-sonnet')
      chat.with_failover({ provider: :bedrock, model: 'claude-3-7-sonnet' }, 'gpt-5')

      expected_failover_configurations = [
        { provider: :bedrock, model: 'claude-3-7-sonnet' },
        { provider: :openai, model: 'gpt-5' }
      ]
      expect(chat.instance_variable_get(:@failover_configurations)).to eq(expected_failover_configurations)
    end

    it 'does not fail over when bad request errors are raised' do
      allow(RubyLLM::Models).to receive(:resolve).and_call_original

      chat = RubyLLM.chat(provider: :anthropic, model: 'claude-3-7-sonnet')
      chat.with_failover({ provider: :bedrock, model: 'claude-3-7-sonnet' })

      prompt = MASSIVE_TEXT_FOR_RATE_LIMIT_TEST * 3

      expect { chat.ask prompt }.to raise_error(RubyLLM::BadRequestError)

      expect(RubyLLM::Models).to have_received(:resolve).once
    end

    it 'can failover with an alternate context' do
      response_message = RubyLLM::Message.new(content: 'Paris', role: :assistant)
      model = RubyLLM::Model::Info.new(id: 'claude-3-7-sonnet', provider: :anthropic)

      # Mock the primary provider (will fail with rate limit)
      primary_provider = instance_double(RubyLLM::Providers::Anthropic)
      primary_connection = instance_double(RubyLLM::Connection)
      allow(primary_provider).to receive_messages(
        connection: primary_connection,
        complete: RubyLLM::RateLimitError.new,
        slug: :anthropic
      )
      allow(primary_provider).to receive(:complete).and_raise(RubyLLM::RateLimitError)

      # Mock the backup provider (will succeed)
      backup_provider = instance_double(RubyLLM::Providers::Anthropic)
      backup_connection = instance_double(RubyLLM::Connection)
      allow(backup_provider).to receive_messages(
        connection: backup_connection,
        complete: response_message,
        slug: :anthropic
      )

      # Configure Models.resolve to return different providers based on context
      allow(RubyLLM::Models).to receive(:resolve) do |_model_id, provider:, assume_exists:, config:|
        _ = provider
        _ = assume_exists
        if config.anthropic_api_key == 'backup-key'
          [model, backup_provider]
        else
          [model, primary_provider]
        end
      end

      chat = RubyLLM.chat(provider: :anthropic, model: 'claude-3-7-sonnet')
      backup_context = RubyLLM.context do |config|
        config.anthropic_api_key = 'backup-key'
      end
      chat.with_failover({ provider: :anthropic, model: 'claude-3-7-sonnet', context: backup_context })

      response = chat.ask "#{MASSIVE_TEXT_FOR_RATE_LIMIT_TEST} What is the capital of France?"

      expect(response.content).to include('Paris')

      # Verify that the backup provider with the backup-key was actually called
      expect(backup_provider).to have_received(:complete).once
    end

    [
      RubyLLM::RateLimitError,
      RubyLLM::ServiceUnavailableError,
      RubyLLM::OverloadedError,
      RubyLLM::ServerError
    ].each do |error_class|
      it "fails over when #{error_class.name.split('::').last} is raised" do
        response_message = RubyLLM::Message.new(content: 'Success', role: :assistant)
        model = RubyLLM::Model::Info.new(id: 'claude-3-7-sonnet', provider: :anthropic)

        # Mock the primary provider (will fail with the specified error)
        primary_provider = instance_double(RubyLLM::Providers::Anthropic)
        primary_connection = instance_double(RubyLLM::Connection)
        allow(primary_provider).to receive_messages(
          connection: primary_connection,
          complete: error_class.new,
          slug: :anthropic
        )
        allow(primary_provider).to receive(:complete).and_raise(error_class)

        # Mock the backup provider (will succeed)
        backup_provider = instance_double(RubyLLM::Providers::Bedrock)
        backup_connection = instance_double(RubyLLM::Connection)
        allow(backup_provider).to receive_messages(
          connection: backup_connection,
          complete: response_message,
          slug: :bedrock
        )

        # Configure Models.resolve to return different providers
        allow(RubyLLM::Models).to receive(:resolve) do |_model_id, provider:, **_kwargs|
          case provider
          when :anthropic
            [model, primary_provider]
          when :bedrock
            [model, backup_provider]
          end
        end

        chat = RubyLLM.chat(provider: :anthropic, model: 'claude-3-7-sonnet')
        chat.with_failover({ provider: :bedrock, model: 'claude-3-7-sonnet' })

        response = chat.ask 'Test question'

        expect(response.content).to eq('Success')
        expect(backup_provider).to have_received(:complete).once
      end
    end
  end

  context 'when restoring context and config' do
    it 'saves original context and config before attempting failover' do
      chat = RubyLLM.chat(provider: :anthropic, model: 'claude-3-7-sonnet')
      original_provider = chat.instance_variable_get(:@provider)
      original_model = chat.instance_variable_get(:@model)
      original_context = chat.instance_variable_get(:@context)
      original_config = chat.instance_variable_get(:@config)

      chat.save_original_context

      expect(chat.instance_variable_get(:@original_provider)).to eq(original_provider)
      expect(chat.instance_variable_get(:@original_model)).to eq(original_model)
      expect(chat.instance_variable_get(:@original_context)).to eq(original_context)
      expect(chat.instance_variable_get(:@original_config)).to eq(original_config)
    end

    it 'restores original context and config when called' do
      chat = RubyLLM.chat(provider: :anthropic, model: 'claude-3-7-sonnet')
      original_provider = chat.instance_variable_get(:@provider)
      original_model = chat.instance_variable_get(:@model)
      original_context = chat.instance_variable_get(:@context)
      original_config = chat.instance_variable_get(:@config)

      chat.save_original_context

      new_context = RubyLLM.context do |config|
        config.anthropic_api_key = 'new-key'
      end
      chat.with_context(new_context)
      chat.with_model('gpt-4', provider: :openai)

      expect(chat.instance_variable_get(:@provider)).not_to eq(original_provider)
      expect(chat.instance_variable_get(:@model)).not_to eq(original_model)
      expect(chat.instance_variable_get(:@context)).not_to eq(original_context)
      expect(chat.instance_variable_get(:@config)).not_to eq(original_config)

      chat.restore_original_context

      expect(chat.instance_variable_get(:@provider)).to eq(original_provider)
      expect(chat.instance_variable_get(:@model)).to eq(original_model)
      expect(chat.instance_variable_get(:@context)).to eq(original_context)
      expect(chat.instance_variable_get(:@config)).to eq(original_config)
    end

    it 'restores original context when all failover configurations fail' do
      model = RubyLLM::Model::Info.new(id: 'claude-3-7-sonnet', provider: :anthropic)

      original_context = RubyLLM.context do |config|
        config.anthropic_api_key = 'original-key'
      end

      # Mock providers that always fail
      failing_provider1 = instance_double(RubyLLM::Providers::Anthropic)
      failing_connection1 = instance_double(RubyLLM::Connection)
      allow(failing_provider1).to receive_messages(
        connection: failing_connection1,
        slug: :anthropic
      )
      allow(failing_provider1).to receive(:complete).and_raise(RubyLLM::RateLimitError)

      failing_provider2 = instance_double(RubyLLM::Providers::Bedrock)
      failing_connection2 = instance_double(RubyLLM::Connection)
      allow(failing_provider2).to receive_messages(
        connection: failing_connection2,
        slug: :bedrock
      )
      allow(failing_provider2).to receive(:complete).and_raise(RubyLLM::RateLimitError)

      # Configure Models.resolve to return failing providers
      allow(RubyLLM::Models).to receive(:resolve) do |_model_id, provider:, **_kwargs|
        case provider
        when :anthropic
          [model, failing_provider1]
        when :bedrock
          [model, failing_provider2]
        end
      end

      chat = RubyLLM.chat(provider: :anthropic, model: 'claude-3-7-sonnet', context: original_context)
      chat.with_failover({ provider: :bedrock, model: 'claude-3-7-sonnet' })

      # Capture original state
      original_provider = chat.instance_variable_get(:@provider)
      original_model = chat.instance_variable_get(:@model)
      original_config = chat.instance_variable_get(:@config)

      expect { chat.ask 'Test question' }.to raise_error(RubyLLM::RateLimitError)

      # Verify that context was restored to original
      expect(chat.instance_variable_get(:@provider)).to eq(original_provider)
      expect(chat.instance_variable_get(:@model)).to eq(original_model)
      expect(chat.instance_variable_get(:@context)).to eq(original_context)
      expect(chat.instance_variable_get(:@config)).to eq(original_config)
    end

    it 'does not restore context when failover succeeds' do
      response_message = RubyLLM::Message.new(content: 'Success', role: :assistant)
      model = RubyLLM::Model::Info.new(id: 'claude-3-7-sonnet', provider: :anthropic)

      original_context = RubyLLM.context do |config|
        config.anthropic_api_key = 'original-key'
      end

      backup_context = RubyLLM.context do |config|
        config.anthropic_api_key = 'backup-key'
      end

      # Mock the primary provider (will fail)
      primary_provider = instance_double(RubyLLM::Providers::Anthropic)
      primary_connection = instance_double(RubyLLM::Connection)
      allow(primary_provider).to receive_messages(
        connection: primary_connection,
        slug: :anthropic
      )
      allow(primary_provider).to receive(:complete).and_raise(RubyLLM::RateLimitError)

      # Mock the backup provider (will succeed)
      backup_provider = instance_double(RubyLLM::Providers::Anthropic)
      backup_connection = instance_double(RubyLLM::Connection)
      allow(backup_provider).to receive_messages(
        connection: backup_connection,
        complete: response_message,
        slug: :anthropic
      )

      # Configure Models.resolve to return different providers based on context
      allow(RubyLLM::Models).to receive(:resolve) do |_model_id, provider:, config:, **_kwargs|
        _ = provider
        if config.anthropic_api_key == 'backup-key'
          [model, backup_provider]
        else
          [model, primary_provider]
        end
      end

      chat = RubyLLM.chat(provider: :anthropic, model: 'claude-3-7-sonnet', context: original_context)
      chat.with_failover({ provider: :anthropic, model: 'claude-3-7-sonnet', context: backup_context })

      response = chat.ask 'Test question'

      expect(response.content).to eq('Success')
      # Verify that context was NOT restored (should still be backup context)
      expect(chat.instance_variable_get(:@context)).to eq(backup_context)
      expect(chat.instance_variable_get(:@config)).to eq(backup_context.config)
    end
  end
end
