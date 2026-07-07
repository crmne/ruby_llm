# frozen_string_literal: true

require 'spec_helper'

# What it takes to be a provider: subclass Provider, register at least one
# protocol to speak, know where to talk (api_base) and how to authenticate
# (headers), and declare its configuration surface (options and requirements).
# The base leaves api_base abstract and defaults the rest, but every shipped
# provider implements all of them, so a new provider that skips one fails at
# load time rather than in production.
RSpec.shared_examples 'a provider' do |provider_class|
  overrides = lambda do |seam, scope|
    if scope == :class
      provider_class.singleton_class.instance_method(seam).owner != RubyLLM::Provider.singleton_class
    else
      provider_class.instance_method(seam).owner != RubyLLM::Provider
    end
  end

  it 'subclasses Provider' do
    expect(provider_class.ancestors).to include(RubyLLM::Provider)
  end

  it 'registers at least one protocol' do
    expect(provider_class.protocols).not_to be_empty
  end

  {
    api_base: :instance,
    headers: :instance,
    configuration_options: :class,
    configuration_requirements: :class
  }.each do |seam, scope|
    it "implements ##{seam}" do
      expect(overrides.call(seam, scope)).to be(true)
    end
  end
end

RSpec.describe RubyLLM::Provider do
  RubyLLM::Provider.providers.each do |name, provider_class| # rubocop:disable RSpec/DescribedClass
    describe(name) { it_behaves_like 'a provider', provider_class }
  end
end
