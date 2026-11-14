# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Provider::Registration do
  describe '.register' do
    it 'finalizes a class-valued registration immediately, matching the Provider.slug contract' do
      provider_class = Class.new(RubyLLM::Provider)

      begin
        RubyLLM::Provider.register(:alloc_test_registration_class, provider_class)

        expect(provider_class.slug).to eq('alloc_test_registration_class')
        expect(RubyLLM::Provider.resolved).to have_key(:alloc_test_registration_class)
      ensure
        RubyLLM::Provider.unregister(:alloc_test_registration_class)
      end
    end

    it 'keeps a registration passed by name unresolved until first use' do
      dynamic_provider = Class.new(RubyLLM::Provider)
      stub_const('RubyLLM::Providers::AllocTestRegistrationString', dynamic_provider)

      begin
        RubyLLM::Provider.register(:alloc_test_registration_string, 'RubyLLM::Providers::AllocTestRegistrationString')

        expect(RubyLLM::Provider.resolved).not_to have_key(:alloc_test_registration_string)

        resolved = RubyLLM::Provider.resolve(:alloc_test_registration_string)

        expect(resolved).to eq(dynamic_provider)
        expect(dynamic_provider.slug).to eq('alloc_test_registration_string')
      ensure
        RubyLLM::Provider.unregister(:alloc_test_registration_string)
      end
    end

    it 'names the slug and keeps the original NameError when a registered class name does not resolve' do
      RubyLLM::Provider.register(:alloc_test_broken_registration, 'RubyLLM::Providers::DoesNotExist')

      expect { RubyLLM::Provider.resolve(:alloc_test_broken_registration) }
        .to raise_error(RubyLLM::ConfigurationError, /alloc_test_broken_registration.*DoesNotExist/) do |error|
          expect(error.cause).to be_a(NameError)
        end
    ensure
      RubyLLM::Provider.unregister(:alloc_test_broken_registration)
    end
  end

  describe 'RubyLLM::Configuration.provider_option?' do
    it 'treats an already-declared option as declared without resolving providers' do
      allow(RubyLLM::Provider).to receive(:resolve_all).and_call_original

      expect(RubyLLM::Configuration.provider_option?(:default_model)).to be(true)
      expect(RubyLLM::Provider).not_to have_received(:resolve_all)
    end

    it 'treats a Ruby implicit-conversion probe as unknown without resolving providers' do
      allow(RubyLLM::Provider).to receive(:resolve_all).and_call_original

      expect(RubyLLM::Configuration.provider_option?(:to_ary)).to be(false)
      expect(RubyLLM::Provider).not_to have_received(:resolve_all)
    end

    it 'never loads a provider to answer a conversion probe sent to a configuration instance' do
      dynamic_provider = Class.new(RubyLLM::Provider)
      stub_const('RubyLLM::Providers::AllocTestConversionProbe', dynamic_provider)

      begin
        RubyLLM::Provider.register(:alloc_test_conversion_probe, 'RubyLLM::Providers::AllocTestConversionProbe')

        expect { Array(RubyLLM::Configuration.new) }.not_to raise_error
        expect(RubyLLM::Provider.resolved).not_to have_key(:alloc_test_conversion_probe)
      ensure
        RubyLLM::Provider.unregister(:alloc_test_conversion_probe)
      end
    end

    it 'resolves a provider whose slug happens to start with to_' do
      provider_class = Class.new(RubyLLM::Provider) do
        class << self
          def configuration_options
            %i[to_service_api_key]
          end
        end
      end
      stub_const('RubyLLM::Providers::ToService', provider_class)

      begin
        RubyLLM::Provider.register(:to_service, 'RubyLLM::Providers::ToService')

        expect(RubyLLM::Configuration.provider_option?(:to_service_api_key)).to be(true)
      ensure
        RubyLLM::Provider.unregister(:to_service)
      end
    end
  end

  describe 'RubyLLM::Configuration.options' do
    it 'includes the options of a provider that has not been resolved yet' do
      provider_class = Class.new(RubyLLM::Provider) do
        class << self
          def configuration_options
            %i[alloc_test_discovery_marker]
          end
        end
      end
      stub_const('RubyLLM::Providers::AllocTestDiscovery', provider_class)

      begin
        RubyLLM::Provider.register(:alloc_test_discovery, 'RubyLLM::Providers::AllocTestDiscovery')

        expect(RubyLLM::Configuration.options).to include(:alloc_test_discovery_marker)
      ensure
        RubyLLM::Provider.unregister(:alloc_test_discovery)
      end
    end
  end

  describe 'RubyLLM::Configuration#secret_values' do
    it 'does not resolve every provider to redact credentials' do
      provider_class = Class.new(RubyLLM::Provider) do
        class << self
          def configuration_options
            %i[alloc_test_secret_api_key]
          end
        end
      end
      stub_const('RubyLLM::Providers::AllocTestSecret', provider_class)

      begin
        RubyLLM::Provider.register(:alloc_test_secret, 'RubyLLM::Providers::AllocTestSecret')

        RubyLLM::Configuration.new.secret_values

        expect(RubyLLM::Provider.resolved).not_to have_key(:alloc_test_secret)
      ensure
        RubyLLM::Provider.unregister(:alloc_test_secret)
      end
    end
  end
end
