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
end
