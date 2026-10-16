# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require_relative '../../support/marketplace_helpers'

RSpec.describe RubyLLM::Skill::Marketplace do
  include MarketplaceHelpers

  include_context 'with configured RubyLLM'

  let(:tmpdir) { Pathname.new(Dir.mktmpdir('ruby_llm-marketplace')).realpath }
  let(:root) { tmpdir.join('vendor/skills') }
  let(:source) { tmpdir.join('acme') }

  before { allow(described_class).to receive(:root).and_return(root) }

  after do
    RubyLLM::Skill.instance_variable_set(:@roots, nil)
    FileUtils.rm_rf(tmpdir)
  end

  def installed
    root.glob('**/*').select(&:file?).map { |file| file.relative_path_from(root).to_s }.sort
  end

  describe '.root' do
    before { allow(described_class).to receive(:root).and_call_original }

    it 'is vendor/skills under the working directory' do
      hide_const('Rails')

      expect(described_class.root).to eq(Pathname.new(Dir.pwd).join('vendor/skills'))
    end

    it 'is vendor/skills under Rails.root in Rails' do
      stub_const('Rails', Module.new { def self.root = Pathname.new('/srv/app') })

      expect(described_class.root).to eq(Pathname.new('/srv/app/vendor/skills'))
    end
  end

  describe '.add' do
    context 'with a directory' do
      before do
        write_skill(source.join('plugins/billing/skills/invoices'))
        write_file(source.join('plugins/billing/skills/invoices/scripts/build.sh'), "#!/bin/sh\n").chmod(0o755)
        write_skill(source.join('plugins/billing/skills/refunds'))
        write_file(source.join('plugins/billing/hooks/hooks.json'), '{}')
        write_skill(source.join('plugins/reports/skills/quarterly'))
        write_marketplace(source, [{ name: 'billing', source: './plugins/billing' },
                                   { name: 'reports', source: './plugins/reports' }])
      end

      it 'copies the skill folders of every plugin and records the source' do
        marketplace = described_class.add(source)

        expect(installed).to eq(%w[
                                  acme-skills/billing/invoices/SKILL.md
                                  acme-skills/billing/invoices/scripts/build.sh
                                  acme-skills/billing/refunds/SKILL.md
                                  acme-skills/marketplace.json
                                  acme-skills/reports/quarterly/SKILL.md
                                ])
        expect(root.join('acme-skills/billing/invoices/scripts/build.sh')).to be_executable
        expect(JSON.parse(root.join('acme-skills/marketplace.json').read)).to eq('source' => source.to_s,
                                                                                 'commit' => nil)
        expect(marketplace).to have_attributes(name: 'acme-skills', source: source.to_s, commit: nil,
                                               path: root.join('acme-skills'), plugins: %w[billing reports])
        expect(marketplace.skills.map(&:name)).to eq(%w[invoices refunds quarterly])
        expect(marketplace.inspect).to start_with('#<RubyLLM::Skill::Marketplace name: "acme-skills", source: ')
      end

      it 'adds only the named plugins' do
        expect(described_class.add(source, only: :reports).plugins).to eq(%w[reports])
        expect(described_class.add(source, only: %w[billing]).plugins).to eq(%w[billing])
      end

      it 'raises for a plugin the marketplace lacks' do
        expect { described_class.add(source, only: 'payroll') }
          .to raise_error(ArgumentError, 'acme-skills has no plugin named payroll. Plugins: billing, reports')
        expect(root).not_to exist
      end

      it 'replaces the skills when added again' do
        described_class.add("#{source}/")
        source.join('plugins/billing/skills/refunds').rmtree
        write_skill(source.join('plugins/billing/skills/credits'))

        expect(described_class.add(source).skills.map(&:name)).to eq(%w[credits invoices quarterly])
      end

      it 'keeps the earlier skills and leaves nothing behind when a skill is invalid' do
        described_class.add(source)
        write_skill(source.join('plugins/reports/skills/yearly'), name: 'annual')

        expect { described_class.add(source) }.to raise_error(RubyLLM::InvalidSkillError, /match its folder name/)
        expect(described_class.find('acme-skills').skills.map(&:name)).to eq(%w[invoices refunds quarterly])
        expect(root.children.map { |child| child.basename.to_s }).to eq(%w[acme-skills])
      end

      it 'refuses a name another source or another folder already has' do
        described_class.add(source)
        other = write_marketplace(tmpdir.join('other'), [{ name: 'billing', source: './' }])
        write_skill(other.join('skills/invoices'))

        expect { described_class.add(other) }
          .to raise_error(ArgumentError, "A marketplace named acme-skills was added from #{source}. Remove it first")

        described_class.find('acme-skills').remove
        write_skill(root.join('acme-skills'))

        expect { described_class.add(source) }.to raise_error(ArgumentError, /exists and is not a marketplace/)
      end
    end

    it 'reads the Codex and Cursor marketplace files and their sources' do
      write_skill(source.join('codex/skills/review'))
      write_marketplace(source, [{ name: 'codex', source: { source: 'local', path: './codex' } }],
                        file: '.agents/plugins/marketplace.json')
      cursor = write_marketplace(tmpdir.join('cursor'), [{ name: 'cursor', source: { path: 'rules' } }],
                                 name: 'cursor-skills', file: '.cursor-plugin/marketplace.json')
      write_skill(cursor.join('rules/skills/lint'))

      expect(described_class.add(source).skills.map(&:name)).to eq(%w[review])
      expect(described_class.add(cursor).skills.map(&:name)).to eq(%w[lint])
    end

    it 'adds the skill paths a plugin entry lists instead of its skills folder' do
      %w[pdf docx brand].each { |name| write_skill(source.join('skills', name)) }
      write_skill(source.join('more/xlsx'))
      source.join('more/linked').mkpath
      File.symlink(source.join('skills/pdf/SKILL.md'), source.join('more/linked/SKILL.md'))
      write_marketplace(source, [{ name: 'documents', source: './', strict: false,
                                   skills: ['./skills/pdf', './skills/docx', './more', './missing'] },
                                 { name: 'design', source: './', strict: false, skills: ['./skills/brand'] }])

      marketplace = described_class.add(source)

      expect(marketplace.skills.map { |skill| skill.path.relative_path_from(root).to_s })
        .to eq(%w[acme-skills/design/brand acme-skills/documents/docx acme-skills/documents/pdf
                  acme-skills/documents/xlsx])
      expect(described_class.add(source, only: 'design').skills.map(&:name)).to eq(%w[brand])
    end

    it 'prefixes bare plugin sources with the plugin root' do
      write_skill(source.join('plugins/tools/skills/grep'))
      write_skill(source.join('local/skills/sed'))
      write_marketplace(source, [{ name: 'tools', source: 'tools' }, { name: 'local', source: './local' }],
                        metadata: { pluginRoot: './plugins' })

      expect(described_class.add(source).skills.map(&:name)).to eq(%w[sed grep])
    end

    it 'leaves out plugins without skills and plugins it cannot fetch, and raises when they are named' do
      write_skill(source.join('billing/skills/invoices'))
      write_file(source.join('hooks/hooks/hooks.json'), '{}')
      write_marketplace(source, [{ name: 'billing', source: './billing' },
                                 { name: 'hooks', source: './hooks' },
                                 { name: 'packaged', source: { source: 'npm', package: 'acme' } },
                                 { name: 'elsewhere', source: { source: 'url', url: 'https://git.example.com/a/b' } },
                                 { name: 'local', source: { source: 'github', repo: '../billing' } },
                                 { name: 'dotted', source: { source: 'url', url: 'https://github.com/../billing' } },
                                 { name: 'odd-ref', source: { source: 'github', repo: 'acme/tools', ref: '../x' } },
                                 { name: 'typed-ref', source: { source: 'github', repo: 'acme/tools', ref: 1 } },
                                 { name: 'missing' }])

      expect(described_class.add(source).plugins).to eq(%w[billing])
      expect { described_class.add(source, only: 'hooks') }
        .to raise_error(RubyLLM::InvalidMarketplaceError, 'The hooks plugin has no skills')
      %w[packaged elsewhere local dotted odd-ref typed-ref missing].each do |name|
        expect { described_class.add(source, only: name) }
          .to raise_error(ArgumentError, "RubyLLM cannot fetch the source of the #{name} plugin")
      end
    end

    it 'never copies through a symbolic link or outside the marketplace' do
      secret = write_file(tmpdir.join('secret/SKILL.md'), "---\nname: secret\ndescription: Private.\n---\n")
      write_skill(source.join('skills/notes'))
      File.symlink(secret, source.join('skills/notes/linked.md'))
      File.symlink(secret.dirname, source.join('skills/secret'))
      write_marketplace(source, [{ name: 'notes', source: './' }])

      described_class.add(source)

      expect(installed).to eq(%w[acme-skills/marketplace.json acme-skills/notes/notes/SKILL.md])

      write_marketplace(source, [{ name: 'notes', source: '../secret' }])
      expect { described_class.add(source) }
        .to raise_error(RubyLLM::InvalidMarketplaceError,
                        'The notes plugin points outside its repository, to ../secret')

      write_marketplace(source, [{ name: 'notes', source: './', skills: ['../secret'] }])
      expect { described_class.add(source) }.to raise_error(RubyLLM::InvalidMarketplaceError, /outside its repository/)
    end

    it 'raises InvalidMarketplaceError for a missing, malformed, or empty marketplace' do
      source.mkpath
      expect { described_class.add(source) }
        .to raise_error(RubyLLM::InvalidMarketplaceError,
                        /\A#{Regexp.escape(source.to_s)} has no marketplace file. Looked for \.claude-plugin/)

      {
        '{' => %r{\A\.claude-plugin/marketplace\.json in #{Regexp.escape(source.to_s)} is not valid JSON},
        '[]' => /must hold a JSON object with a plugins array/,
        '{"name":"acme","plugins":["billing"]}' => /must hold a JSON object with a plugins array/,
        '{"name":"../acme","plugins":[]}' => %r{names the marketplace "\.\./acme"},
        '{"name":"acme","plugins":[{"name":"a/b","source":"./"}]}' => %r{names a plugin "a/b"},
        '{"name":"acme","plugins":[{"name":"a","source":"./"},{"name":"a","source":"./"}]}' => /lists a more than once/,
        '{"name":"acme","plugins":[{"name":"marketplace.json","source":"./"}]}' => /names a plugin "marketplace.json"/,
        "\uFEFF{\"name\":\"acme\",\"plugins\":[]}" => /has no skills to add/
      }.each do |content, message|
        write_file(source.join('.claude-plugin/marketplace.json'), content)

        expect { described_class.add(source) }.to raise_error(RubyLLM::InvalidMarketplaceError, message)
      end
      expect(root.exist? ? root.children : []).to eq([])
    end

    it 'raises ArgumentError for a source that is neither a directory nor a repository' do
      ['', 'acme', 'https://github.com/acme/skills', 'acme/skills@', 'acme/skills@a b', 'acme/..', '../acme',
       'acme/skills@../../x'].each do |invalid|
        expect { described_class.add(invalid) }
          .to raise_error(ArgumentError, %r{is neither a directory nor a GitHub repository like owner/repo})
      end
    end

    context 'with a GitHub repository' do
      let(:files) do
        {
          '.claude-plugin/marketplace.json' => JSON.generate(
            name: 'acme-skills', plugins: [{ name: 'billing', source: './plugins/billing' }]
          ),
          'plugins/billing/skills/invoices/SKILL.md' => "---\nname: invoices\ndescription: Bills orders.\n---\n",
          'plugins/billing/skills/invoices/scripts/build.sh' => [0o755, "#!/bin/sh\n"],
          'plugins/billing/skills/invoices/linked.md' => :'/etc/passwd',
          'README.md' => 'Acme'
        }
      end

      it 'downloads the default branch as one archive and records its commit' do
        request = stub_repository('acme/skills', files)

        marketplace = described_class.add('acme/skills')

        expect(request).to have_been_requested.once
        expect(marketplace).to have_attributes(source: 'acme/skills', commit: MarketplaceHelpers::COMMIT)
        expect(installed).to eq(%w[
                                  acme-skills/billing/invoices/SKILL.md
                                  acme-skills/billing/invoices/scripts/build.sh
                                  acme-skills/marketplace.json
                                ])
        expect(root.join('acme-skills/billing/invoices/scripts/build.sh')).to be_executable
      end

      it 'downloads the branch, tag, or commit after @, and replaces a marketplace pinned elsewhere' do
        stub_repository('acme/skills', files)
        stub_repository('acme/skills', files, ref: 'v1.2.0', commit: 'a' * 40)
        described_class.add('acme/skills')

        marketplace = described_class.add('acme/skills@v1.2.0')

        expect(marketplace).to have_attributes(source: 'acme/skills@v1.2.0', commit: 'a' * 40)
      end

      it 'extracts files whose long names the archive keeps in an extended header' do
        long = "plugins/billing/skills/invoices/references/#{'tax-rules-' * 9}.md"
        stub_repository('acme/skills', files.merge(long => 'Rates'))

        described_class.add('acme/skills')

        expect(root.join('acme-skills/billing/invoices/references', "#{'tax-rules-' * 9}.md").read).to eq('Rates')
      end

      it 'records no commit when the archive names none' do
        stub_repository('acme/skills', files, commit: nil)

        expect(described_class.add('acme/skills').commit).to be_nil
      end

      it 'fetches plugins that live in repositories of their own' do
        skill = { 'skills/review/SKILL.md' => "---\nname: review\ndescription: Reviews code.\n---\n" }
        nested = skill.transform_keys { |path| "tools/lint/#{path.sub('review', 'lint')}" }
                      .transform_values { |content| content.sub('review', 'lint') }
        plugins = [{ name: 'review', source: { source: 'github', repo: 'acme/review', ref: 'stable' } },
                   { name: 'pinned', source: { source: 'github', repo: 'acme/review', ref: 'main', sha: 'b' * 40 } },
                   { name: 'cloned', source: { source: 'url', url: 'https://github.com/acme/review.git' } },
                   { name: 'ssh', source: { source: 'url', url: 'git@github.com:acme/review.git' } },
                   { name: 'lint', source: { source: 'git-subdir', url: 'https://github.com/acme/mono',
                                             path: 'tools/lint', ref: 'v2' } }]
        stub_repository('acme/skills',
                        { '.claude-plugin/marketplace.json' => JSON.generate(name: 'acme-skills', plugins:) })
        [['stable', skill], ['b' * 40, skill], ['HEAD', skill]].each do |ref, tree|
          stub_repository('acme/review', tree, ref:)
        end
        stub_repository('acme/mono', nested, ref: 'v2')

        marketplace = described_class.add('acme/skills')

        expect(marketplace.plugins).to eq(%w[cloned lint pinned review ssh])
        expect(marketplace.skills.map(&:name)).to eq(%w[review lint review review review])
      end

      it 'raises MarketplaceNotFoundError when GitHub has no such repository' do
        stub_request(:get, 'https://codeload.github.com/acme/missing/tar.gz/HEAD').to_return(status: 404)

        expect { described_class.add('acme/missing') }
          .to raise_error(RubyLLM::MarketplaceNotFoundError, 'No GitHub repository acme/missing')
      end

      it 'refuses archives that are not tar.gz, leave the folder, or expand past the limit' do
        stub_request(:get, 'https://codeload.github.com/acme/skills/tar.gz/HEAD').to_return(body: 'not gzip')
        expect { described_class.add('acme/skills') }
          .to raise_error(RubyLLM::InvalidMarketplaceError, 'acme/skills did not return a gzip archive')

        stub_request(:get, 'https://codeload.github.com/acme/skills/tar.gz/HEAD')
          .to_return(body: Zlib.gzip('not a tar archive' * 100))
        expect { described_class.add('acme/skills') }
          .to raise_error(RubyLLM::InvalidMarketplaceError, 'acme/skills did not return a tar archive')

        stub_repository('acme/skills', files.merge('plugins/../../escape.md' => 'x'))
        expect { described_class.add('acme/skills') }
          .to raise_error(RubyLLM::InvalidMarketplaceError, %r{acme/skills holds an unsafe path, "repo-main/plugins/})

        stub_const('RubyLLM::Skill::Marketplace::Repository::MAX_BYTES', 1024)
        stub_repository('acme/skills', files.merge('big.bin' => 'x' * 4096))
        expect { described_class.add('acme/skills') }
          .to raise_error(RubyLLM::InvalidMarketplaceError, 'acme/skills is larger than 1024 bytes')
        expect(tmpdir.join('escape.md')).not_to exist
      end
    end
  end

  describe '.all and .find' do
    before do
      %w[zeta alpha].each do |name|
        write_skill(tmpdir.join(name, 'skills', "#{name}-skill"))
        described_class.add(write_marketplace(tmpdir.join(name), [{ name: 'main', source: './' }], name:))
      end
      write_skill(root.join('by-hand'))
    end

    it 'lists the marketplaces by name' do
      expect(described_class.all.map(&:name)).to eq(%w[alpha zeta])
    end

    it 'finds a marketplace by name and raises for one that was never added' do
      expect(described_class.find(:zeta).skills.map(&:name)).to eq(%w[zeta-skill])
      expect { described_class.find('by-hand') }
        .to raise_error(RubyLLM::MarketplaceNotFoundError, "No marketplace named by-hand in #{root}")
      expect { described_class.find('../zeta') }.to raise_error(RubyLLM::MarketplaceNotFoundError)
    end

    it 'raises InvalidMarketplaceError for a record it cannot read' do
      root.join('alpha/marketplace.json').write('[]')

      expect { described_class.all }
        .to raise_error(RubyLLM::InvalidMarketplaceError,
                        "#{root.join('alpha/marketplace.json')} is not a marketplace record")
    end
  end

  describe '#update' do
    it 'fetches the source again, keeps the plugin selection, and moves the commit' do
      marketplace_file = JSON.generate(name: 'acme-skills', plugins: [{ name: 'billing', source: './billing' },
                                                                      { name: 'reports', source: './reports' }])
      skill = ->(name) { "---\nname: #{name}\ndescription: Does #{name}.\n---\n" }
      stub_repository('acme/skills', { '.claude-plugin/marketplace.json' => marketplace_file,
                                       'billing/skills/invoices/SKILL.md' => skill['invoices'],
                                       'reports/skills/quarterly/SKILL.md' => skill['quarterly'] })
      marketplace = described_class.add('acme/skills', only: 'billing')
      stub_repository('acme/skills', { '.claude-plugin/marketplace.json' => marketplace_file,
                                       'billing/skills/credits/SKILL.md' => skill['credits'],
                                       'reports/skills/quarterly/SKILL.md' => skill['quarterly'] }, commit: 'c' * 40)

      expect(marketplace.update).to equal(marketplace)
      expect(marketplace).to have_attributes(commit: 'c' * 40, plugins: %w[billing])
      expect(marketplace.skills.map(&:name)).to eq(%w[credits])
    end
  end

  describe '#remove' do
    it 'deletes the marketplace folder' do
      write_skill(source.join('skills/invoices'))
      marketplace = described_class.add(write_marketplace(source, [{ name: 'billing', source: './' }]))

      expect(marketplace.remove).to equal(marketplace)
      expect(root.join('acme-skills')).not_to exist
      expect(described_class.all).to eq([])
    end
  end

  describe 'skill lookup' do
    before do
      write_skill(source.join('skills/invoices'), description: 'From the marketplace.')
      write_skill(source.join('skills/refunds'))
      described_class.add(write_marketplace(source, [{ name: 'billing', source: './' }]))
      RubyLLM::Skill.roots << write_skill(tmpdir.join('app/skills/invoices'), description: 'From the app.').dirname
    end

    it 'finds marketplace skills after the skill roots' do
      expect(RubyLLM::Skill.find(:refunds).path).to eq(root.join('acme-skills/billing/refunds'))
      expect(RubyLLM::Skill.find(:invoices).description).to eq('From the app.')
      expect(RubyLLM::Skill.all.map(&:name)).to eq(%w[invoices refunds])
      expect { RubyLLM::Skill.find(:missing) }
        .to raise_error(RubyLLM::SkillNotFoundError, /#{Regexp.escape(root.join('acme-skills/billing').to_s)}\z/)
    end

    it 'gives them to a chat' do
      chat = RubyLLM.chat(model: model_for(:openai), provider: :openai)

      expect(chat.with_skills.skills.map(&:description)).to eq(['From the app.', 'Does refunds.'])
      expect(chat.with_skills(false).with_skills(:refunds).skills.map(&:name)).to eq(%w[refunds])
    end
  end

  describe 'rake tasks' do
    def rake(task, *arguments)
      script = "require 'rake'; load 'tasks/ruby_llm.rake'; Rake::Task[ARGV.shift].invoke(*ARGV)"
      library = File.expand_path('../../../lib', __dir__)
      output, error, status = Open3.capture3({ 'LC_ALL' => 'C.UTF-8' }, RbConfig.ruby, '-I', library, '-e', script,
                                             task, *arguments, chdir: tmpdir.to_s)
      expect(status).to be_success, error
      output
    end

    it 'add, list, update, and remove a marketplace in vendor/skills' do
      write_skill(source.join('billing/skills/invoices'))
      write_skill(source.join('reports/skills/quarterly'))
      write_marketplace(source, [{ name: 'billing', source: './billing' }, { name: 'reports', source: './reports' }])

      expect(rake('ruby_llm:marketplaces:add', 'acme', 'billing'))
        .to eq("Added 1 skills to #{root.join('acme-skills')}\n")
      expect(rake('ruby_llm:marketplaces')).to eq("acme-skills (acme): invoices\n")

      write_skill(source.join('billing/skills/refunds'))

      expect(rake('ruby_llm:marketplaces:update')).to eq("Updated acme-skills to acme\n")
      expect(rake('ruby_llm:marketplaces')).to eq("acme-skills (acme): invoices, refunds\n")
      expect(rake('ruby_llm:marketplaces:remove', 'acme-skills')).to eq("Removed #{root.join('acme-skills')}\n")
      expect(root.children).to eq([])
    end
  end
end
