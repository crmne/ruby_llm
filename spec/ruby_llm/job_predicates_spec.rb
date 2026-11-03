# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'job predicates' do # rubocop:disable RSpec/DescribeClass
  let(:protocol) { instance_double(RubyLLM::Protocols::Files) }

  def video_job(status)
    allow(protocol).to receive_messages(provider: instance_double(RubyLLM::Provider, slug: 'xai'),
                                        config: RubyLLM.config)
    RubyLLM::VideoJob.new(id: 'job', protocol:, status:, model: 'grok-imagine-video')
  end

  def research_job(status)
    allow(protocol).to receive(:config).and_return(RubyLLM.config)
    RubyLLM::ResearchJob.new(id: 'job', provider: :vertexai, agent: 'agent', protocol:, status:)
  end

  def task(status)
    RubyLLM::Task.new(status:)
  end

  it 'means finished either way by complete?' do
    expect([video_job(:pending), research_job(:pending), task(:working)].map(&:complete?)).to all(be(false))
    expect([video_job(:failed), research_job(:failed), research_job(:incomplete), task(:cancelled)].map(&:complete?))
      .to all(be(true))
  end

  it 'means finished with a result by succeeded?' do
    expect([video_job(:completed), research_job(:completed), task(:completed)].map(&:succeeded?)).to all(be(true))
    expect([video_job(:failed), research_job(:incomplete), task(:failed), task(:working)].map(&:succeeded?))
      .to all(be(false))
  end

  it 'leaves status values alone' do
    expect([video_job(:completed), research_job(:completed), task(:completed)].map(&:status)).to all(eq(:completed))
  end

  describe 'deprecated names' do
    around do |example|
      behavior = RubyLLM.config.deprecation_behavior
      RubyLLM.config.deprecation_behavior = :raise
      example.run
    ensure
      RubyLLM.config.deprecation_behavior = behavior
    end

    it 'warns through the deprecator and names the replacement' do
      expect { task(:completed).done? }
        .to raise_error(RubyLLM::DeprecationError, /RubyLLM::Task#done\? .*RubyLLM 3\.0.*RubyLLM::Task#complete\?/)
      expect { research_job(:completed).completed? }
        .to raise_error(RubyLLM::DeprecationError,
                        /RubyLLM::ResearchJob#completed\? .*RubyLLM 3\.0.*RubyLLM::ResearchJob#succeeded\?/)
      expect { video_job(:pending).done? }.to raise_error(RubyLLM::DeprecationError, /RubyLLM::VideoJob#done\?/)
    end

    it 'still answers' do
      RubyLLM.config.deprecation_behavior = :silence

      expect(task(:failed)).to have_attributes(done?: true, completed?: false)
      expect(video_job(:completed)).to have_attributes(done?: true, completed?: true)
      expect(research_job(:pending)).to have_attributes(done?: false, completed?: false)
    end
  end
end
