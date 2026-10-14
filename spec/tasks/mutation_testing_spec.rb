# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require_relative '../../tasks/support/mutation_testing'

RSpec.describe MutationTesting do
  let(:repository) { File.expand_path('../..', __dir__) }

  let(:root) { Dir.mktmpdir('mutation-testing') }

  after do
    FileUtils.chmod_R('u+w', root)
    FileUtils.rm_rf(root)
  end

  def write(path, content = '')
    full = File.join(root, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
  end

  def report(survivors: [], killed: 0, file: 'lib/ruby_llm/a.rb')
    {
      'schema_version' => '1.7',
      'summary' => { 'total' => killed + survivors.size, 'killed' => killed, 'survived' => survivors.size,
                     'timeout' => 0, 'errored' => 0, 'score' => nil, 'scoped' => false,
                     'legacy_id_matches' => { 'ignore' => 0, 'baseline' => 1 } },
      'survivors' => survivors,
      'per_source' => [{ 'file' => file, 'total' => killed + survivors.size, 'killed' => killed,
                         'survived' => survivors.size, 'no_coverage' => 0, 'score' => nil }]
    }
  end

  def survivor(file, line, id)
    { 'file' => file, 'line' => line, 'operator' => 'comparison', 'id' => id, 'subject' => 'A#b',
      'diff' => "--- a\n+++ b\n-x\n+y\n" }
  end

  describe '.shards' do
    it 'puts every library source in exactly one shard of the pass that can load it' do
      shards = described_class.shards(repository)
      sources = shards.flat_map(&:sources)

      expect(sources).to match_array(described_class.sources(repository))
      expect(sources.uniq.size).to eq(sources.size)
      rails = shards.select { |shard| shard.pass.rails? }.flat_map(&:sources)
      expect(rails).to include('lib/ruby_llm/active_record/chat_methods.rb', 'lib/ruby_llm/railtie.rb')
      expect(rails).to all(match(%r{\Alib/ruby_llm/(active_record/|railtie\.rb)}))
    end

    it 'catches a source in a new directory in the last shard of its pass' do
      write('lib/ruby_llm/brand_new/thing.rb')
      write('lib/ruby_llm/active_record/brand_new.rb')

      shards = described_class.shards(root)

      expect(shards.map(&:name)).to eq(%w[rails other])
      expect(shards.last.sources).to eq(['lib/ruby_llm/brand_new/thing.rb'])
    end
  end

  describe MutationTesting::Pass do
    it 'splits the specs between the plain and Rails passes and leaves out generator specs' do
      write('spec/ruby_llm/chat_spec.rb', "require 'spec_helper'")
      write('spec/ruby_llm/active_record/chat_spec.rb', "require 'rails_helper'")
      write('spec/ruby_llm/generators/install_spec.rb', "require 'rails_helper'")
      write('spec/dummy/app/thing_spec.rb')

      expect(MutationTesting::PASSES[:plain].specs(root)).to eq(['spec/ruby_llm/chat_spec.rb'])
      expect(MutationTesting::PASSES[:rails].specs(root)).to eq(['spec/ruby_llm/active_record/chat_spec.rb'])
    end
  end

  describe '.environment' do
    it 'replays cassettes without recording and keeps its own Rails database' do
      environment = described_class.environment(MutationTesting::PASSES[:rails], 'full')

      expect(environment).to include('CI' => '1', 'TEST_ENV_NUMBER' => '-mutineer-full', 'RAILS_ENV' => 'test')
    end
  end

  describe MutationTesting::Fingerprint do
    let(:shard) { MutationTesting::Shard.new(name: 'a', pass: MutationTesting::PASSES[:plain], sources: ['lib/a.rb']) }

    before do
      write('lib/a.rb', 'a = 1')
      write('lib/b.rb', 'b = 1')
      write('spec/a_spec.rb', 'it')
    end

    def digest = described_class.new(root).shard(shard)

    it 'changes with the shard sources and the spec tree, not with other sources' do
      original = digest
      write('lib/b.rb', 'b = 2')
      expect(digest).to eq(original)

      write('lib/a.rb', 'a = 2')
      changed_source = digest
      expect(changed_source).not_to eq(original)

      write('spec/fixtures/vcr_cassettes/a.yml', 'recorded')
      expect(digest).not_to eq(changed_source)
    end
  end

  describe MutationTesting::CassetteLock do
    let(:cassettes) { File.join(root, 'spec/fixtures/vcr_cassettes') }
    let(:nested) { File.join(cassettes, 'nested') }

    before { FileUtils.mkdir_p(nested) }

    def mode(dir) = File.stat(dir).mode & 0o777

    it 'makes cassette directories read-only until the last holder releases them' do
      first = described_class.new(root).acquire('full')
      expect([mode(cassettes), mode(nested)]).to eq([0o555, 0o555])
      expect { File.write(File.join(nested, 'new.yml'), '') }.to raise_error(Errno::EACCES)

      first.release

      expect([mode(cassettes), mode(nested)]).to eq([0o755, 0o755])
    end

    it 'keeps the directories read-only while another live holder remains' do
      lock = described_class.new(root)
      lock.acquire('full')
      holder = File.join(root, MutationTesting::STATE_DIR, 'cassette-lock', 'holder-1.json')
      File.write(holder, JSON.generate(pid: 1, boot: lock.send(:boot_id), label: 'check'))

      lock.release

      expect(mode(cassettes)).to eq(0o555)
      FileUtils.rm_f(holder)
      lock.prune
      expect(mode(cassettes)).to eq(0o755)
    end

    it 'restores the directories when the holder died without releasing them' do
      described_class.new(root).acquire('full')
      holder = File.join(root, MutationTesting::STATE_DIR, 'cassette-lock', "holder-#{Process.pid}.json")
      File.write(holder, JSON.generate(pid: Process.pid, boot: 'an earlier boot', label: 'full'))

      described_class.new(root).prune

      expect(mode(cassettes)).to eq(0o755)
    end
  end

  describe MutationTesting::Report do
    before do
      require 'mutineer'
    rescue LoadError
      skip 'mutineer runs on Ruby 3.4 and later'
    end

    it 'combines shard reports into one report mutineer accepts as a baseline' do
      first = report(killed: 3, survivors: [survivor('lib/ruby_llm/b.rb', 4, 'bbbbbbbbbbbb')])
      second = report(killed: 1, survivors: [survivor('lib/ruby_llm/a.rb', 9, 'aaaaaaaaaaaa')])

      combined = described_class.combine([first, second])

      expect(combined['summary']).to include('total' => 6, 'killed' => 4, 'survived' => 2, 'score' => 66.7,
                                             'legacy_id_matches' => { 'ignore' => 0, 'baseline' => 2 })
      expect(combined['survivors'].pluck('id')).to eq(%w[aaaaaaaaaaaa bbbbbbbbbbbb])
      path = File.join(root, 'report.json')
      File.write(path, JSON.generate(combined))
      expect(Mutineer::Baseline.load(path).score).to eq(66.7)
    end

    it 'renders the combined report with mutineer’s HTML report' do
      combined = described_class.combine([report(killed: 1,
                                                 survivors: [survivor(
                                                   'lib/ruby_llm/a.rb', 9, 'abcdefabcdef'
                                                 )])])

      html = described_class.html(combined)

      expect(html).to include('Score: 50.0%', 'lib/ruby_llm/a.rb:9', 'abcdefabcdef')
    end

    it 'scores a run with no covered mutants as nil' do
      expect(described_class.combine([])['summary']).to include('score' => nil)
    end
  end

  describe MutationTesting::FullRun do
    let(:run) { described_class.new(root, out: StringIO.new) }
    let(:shard) { run.shards.first }

    before do
      write('lib/ruby_llm/thing.rb', 'x = 1')
      write('spec/ruby_llm/thing_spec.rb', 'it')
    end

    def finish(digest:, failed: false)
      FileUtils.mkdir_p(File.dirname(run.path(shard, 'json')))
      File.write(run.path(shard, 'json'), JSON.generate(report)) unless failed
      File.write(run.path(shard, 'meta.json'), JSON.generate(digest:, failed:))
    end

    it 'treats a shard as done only while its digest matches' do
      expect(run.state(shard)).to eq(:pending)

      finish(digest: MutationTesting::Fingerprint.new(root).shard(shard))
      expect(run.state(shard)).to eq(:done)

      write('lib/ruby_llm/thing.rb', 'x = 2')
      expect(described_class.new(root).state(shard)).to eq(:stale)
    end

    it 'marks a shard whose run produced no report as failed' do
      finish(digest: MutationTesting::Fingerprint.new(root).shard(shard), failed: true)

      expect(run.state(shard)).to eq(:failed)
    end

    it 'runs a shard again when a pause left it with timeouts' do
      attempts = 0
      allow(run).to receive(:execute) do
        attempts += 1
        run.instance_variable_set(:@frozen, attempts == 1)
        report.tap { |document| document['summary']['timeout'] = 2 if attempts == 1 }
      end
      allow(run).to receive(:write_report)

      expect(run.call).to be(true)
      expect(attempts).to eq(2)
    end
  end

  describe MutationTesting::SpecSelection do
    let(:pass) { MutationTesting::PASSES[:plain] }

    before do
      %w[spec/ruby_llm/chat_spec.rb spec/ruby_llm/cost_spec.rb spec/ruby_llm/agent_spec.rb].each { |spec| write(spec) }
      write('tmp/mutineer/cache/chat/coverage.json',
            JSON.generate(map: { 'lib/ruby_llm/cost.rb:3' => ['spec/ruby_llm/chat_spec.rb'] }))
    end

    it 'takes the specs that covered a source, and its own spec' do
      expect(described_class.new(root).for(pass, ['lib/ruby_llm/cost.rb']))
        .to eq(%w[spec/ruby_llm/chat_spec.rb spec/ruby_llm/cost_spec.rb])
    end

    it 'takes the whole suite for a source no coverage map knows' do
      expect(described_class.new(root).for(pass, ['lib/ruby_llm/agent.rb'])).to eq(pass.specs(root))
    end
  end

  describe MutationTesting::Background do
    it 'starts the full run as an idle-priority systemd user unit that unlocks the cassettes when it stops' do
      background = described_class.new(root, out: StringIO.new)
      allow(background).to receive_messages(active?: false, system: true)

      expect(background.start).to be(true)

      expect(background).to have_received(:system) do |*arguments|
        expect(arguments.first(6)).to eq(['systemd-run', '--user', '--unit=ruby_llm-mutineer', '--collect', '--quiet',
                                          "--working-directory=#{root}"])
        expect(arguments.each_cons(2).filter_map { |flag, value| value if flag == '-p' }).to eq(
          ['Nice=19', 'CPUSchedulingPolicy=idle', 'CPUWeight=idle', 'IOSchedulingClass=idle',
           %(ExecStopPost="#{RbConfig.ruby}" "#{root}/bin/mutineer" unlock)]
        )
        expect(arguments.last(3)).to eq([RbConfig.ruby, "#{root}/bin/mutineer", 'full'])
      end
    end
  end
end
