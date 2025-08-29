# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Models do
  include_context 'with configured RubyLLM'

  describe 'local provider model fetching' do
    describe '.refresh!' do
      context 'with default parameters' do # rubocop:disable RSpec/NestedGroups
        it 'includes local providers' do
          allow(described_class).to receive(:fetch_from_parsera).and_return([])
          allow(RubyLLM::Provider).to receive(:configured_providers).and_return([])

          described_class.refresh!

          expect(RubyLLM::Provider).to have_received(:configured_providers)
        end
      end

      context 'with remote_only: true' do # rubocop:disable RSpec/NestedGroups
        it 'excludes local providers' do
          allow(described_class).to receive(:fetch_from_parsera).and_return([])
          allow(RubyLLM::Provider).to receive(:configured_remote_providers).and_return([])

          described_class.refresh!(remote_only: true)

          expect(RubyLLM::Provider).to have_received(:configured_remote_providers)
        end
      end
    end

    describe '.fetch_from_providers' do
      it 'defaults to remote_only: true' do
        allow(RubyLLM::Provider).to receive(:configured_remote_providers).and_return([])

        described_class.fetch_from_providers

        expect(RubyLLM::Provider).to have_received(:configured_remote_providers)
      end

      it 'can include local providers with remote_only: false' do
        allow(RubyLLM::Provider).to receive(:configured_providers).and_return([])

        described_class.fetch_from_providers(remote_only: false)

        expect(RubyLLM::Provider).to have_received(:configured_providers)
      end
    end

    describe 'Ollama models integration' do
      let(:ollama) { RubyLLM::Providers::Ollama.new(RubyLLM.config) }

      it 'responds to list_models' do
        expect(ollama).to respond_to(:list_models)
      end

      it 'can parse list models response' do
        response = double( # rubocop:disable RSpec/VerifiedDoubles
          'Response',
          body: {
            'data' => [
              {
                'id' => 'llama3:latest',
                'created' => 1_234_567_890,
                'owned_by' => 'library'
              }
            ]
          }
        )

        models = ollama.parse_list_models_response(response, 'ollama', nil)
        expect(models).to be_an(Array)
        expect(models.first).to be_a(RubyLLM::Model::Info)
        expect(models.first.id).to eq('llama3:latest')
        expect(models.first.provider).to eq('ollama')
        expect(models.first.capabilities).to include('streaming', 'function_calling', 'vision')
      end
    end

    describe 'GPUStack models integration' do
      let(:gpustack) { RubyLLM::Providers::GPUStack.new(RubyLLM.config) }

      it 'responds to list_models' do
        expect(gpustack).to respond_to(:list_models)
      end
    end

    describe 'local provider model resolution' do
      it 'assumes model exists for Ollama without warning after refresh' do
        allow_any_instance_of(RubyLLM::Providers::Ollama).to( # rubocop:disable RSpec/AnyInstance
          receive(:list_models).and_return([
                                             RubyLLM::Model::Info.new(
                                               id: 'test-model',
                                               provider: 'ollama',
                                               name: 'Test Model',
                                               capabilities: %w[streaming
                                                                function_calling]
                                             )
                                           ])
        )
        allow(RubyLLM.logger).to receive(:warn)

        described_class.refresh!

        chat = RubyLLM.chat(provider: :ollama, model: 'test-model')
        expect(chat.model.id).to eq('test-model')
        expect(RubyLLM.logger).not_to have_received(:warn)
      end

      it 'assumes model exists for GPUStack without checking registry' do
        chat = RubyLLM.chat(provider: :gpustack, model: 'any-model')
        expect(chat.model.id).to eq('any-model')
        expect(chat.model.provider).to eq('gpustack')
      end
    end
  end
end
