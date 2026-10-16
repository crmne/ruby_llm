# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Skill do
  let(:fixtures) { File.expand_path('../fixtures/skills', __dir__) }
  let(:tmpdir) { Pathname.new(Dir.mktmpdir('ruby_llm-skills')) }

  after do
    described_class.instance_variable_set(:@roots, nil)
    FileUtils.rm_rf(tmpdir)
  end

  def write_skill(name, front_matter, body = "Do the thing.\n", root: tmpdir)
    folder = root.join(name)
    folder.mkpath
    folder.join('SKILL.md').write("---\n#{front_matter}---\n#{body}")
    folder
  end

  describe '.new' do
    it 'reads a skill under a path the locale left without an encoding' do
      folder = write_skill('pdf-forms', "name: pdf-forms\ndescription: Fills PDF forms.\n", root: tmpdir.join('café'))

      expect(described_class.new(folder.to_s.b).name).to eq('pdf-forms')
    end

    it 'reads the front matter and the instructions' do
      skill = described_class.new(File.join(fixtures, 'ticket-codes'))

      expect(skill.name).to eq('ticket-codes')
      expect(skill.description).to start_with('Builds the official code for a support ticket number.')
      expect(skill.license).to eq('MIT')
      expect(skill.metadata).to eq('author' => 'ruby_llm', 'version' => '1.0')
      expect(skill.compatibility).to be_nil
      expect(skill.allowed_tools).to eq([])
      expect(skill.path).to eq(Pathname.new(fixtures).join('ticket-codes'))
      expect(skill.instructions).to start_with("\n# Ticket codes")
      expect(skill.inspect).to start_with('#<RubyLLM::Skill name: "ticket-codes", description: ')
    end

    it 'reads the optional fields and ignores keys the specification does not define' do
      folder = write_skill('pdf-tools', <<~YAML)
        name: pdf-tools
        description: Fills PDF forms.
        compatibility: Requires poppler
        allowed-tools: Bash(pdftotext:*) Read
        metadata:
          version: 2
        x-vendor-flag: true
      YAML

      skill = described_class.new(folder)

      expect(skill.compatibility).to eq('Requires poppler')
      expect(skill.allowed_tools).to eq(%w[Bash(pdftotext:*) Read])
      expect(skill.metadata).to eq('version' => '2')
    end

    it 'accepts a Pathname, a relative path, and a byte order mark' do
      folder = tmpdir.join('notes')
      folder.mkpath
      folder.join('SKILL.md').write("\uFEFF---\nname: notes\ndescription: Takes notes.\n---\nBody\n")

      expect(described_class.new(folder).name).to eq('notes')
      Dir.chdir(tmpdir) { expect(described_class.new('notes').path).to eq(folder.realpath) }
    end

    it 'raises SkillNotFoundError without a folder or a SKILL.md' do
      tmpdir.join('empty').mkpath

      expect { described_class.new(tmpdir.join('missing')) }.to raise_error(RubyLLM::SkillNotFoundError, /missing/)
      expect { described_class.new(tmpdir.join('empty')) }.to raise_error(RubyLLM::SkillNotFoundError, /SKILL\.md/)
    end

    {
      'no front matter' => [nil, /must start with YAML front matter/],
      'front matter that is not a mapping' => ["- a\n- b\n", /must be a YAML mapping/],
      'invalid YAML' => ["name: [unclosed\n", /not valid YAML/],
      'no name' => ["description: Does things.\n", /needs a name/],
      'no description' => ["name: broken\n", /needs a description/],
      'a blank description' => ["name: broken\ndescription: '  '\n", /needs a description/],
      'a description that is not a string' => ["name: broken\ndescription: [a]\n", /description must be a string/],
      'an uppercase name' => ["name: Broken\ndescription: Does things.\n", /lowercase letters/],
      'a leading hyphen' => ["name: -broken\ndescription: Does things.\n", /lowercase letters/],
      'consecutive hyphens' => ["name: bro--ken\ndescription: Does things.\n", /lowercase letters/],
      'a name that is not the folder name' => ["name: other\ndescription: Does things.\n", /match its folder name/],
      'a description over 1024 characters' => ["name: broken\ndescription: #{'a' * 1025}\n", /at most 1024/],
      'compatibility over 500 characters' =>
        ["name: broken\ndescription: Does things.\ncompatibility: #{'a' * 501}\n", /at most 500/],
      'metadata that is not a mapping' => ["name: broken\ndescription: Does things.\nmetadata: x\n", /metadata/]
    }.each do |problem, (front_matter, message)|
      it "raises InvalidSkillError for #{problem}" do
        folder = tmpdir.join('broken')
        folder.mkpath
        folder.join('SKILL.md').write(front_matter ? "---\n#{front_matter}---\nBody\n" : "# Just Markdown\n")

        expect { described_class.new(folder) }
          .to raise_error(RubyLLM::InvalidSkillError, %r{broken/SKILL\.md .*}) { |error|
            expect(error.message).to match(message)
          }
      end
    end

    it 'accepts a 64-character name and rejects a 65-character one' do
      ok = write_skill('a' * 64, "name: #{'a' * 64}\ndescription: Long.\n")
      long = write_skill('a' * 65, "name: #{'a' * 65}\ndescription: Long.\n")

      expect(described_class.new(ok).name.length).to eq(64)
      expect { described_class.new(long) }.to raise_error(RubyLLM::InvalidSkillError, /at most 64/)
    end
  end

  describe '.roots' do
    it 'starts with app/skills under the working directory' do
      hide_const('Rails')

      expect(described_class.roots.to_a).to eq([Pathname.new(Dir.pwd).join('app/skills')])
    end

    it 'starts with app/skills under Rails.root in Rails' do
      stub_const('Rails', Module.new { def self.root = Pathname.new('/srv/app') })

      expect(described_class.roots.first).to eq(Pathname.new('/srv/app/app/skills'))
    end

    it 'finds skills in appended roots, with earlier roots first' do
      engine = tmpdir.join('engine')
      write_skill('ticket-codes', "name: ticket-codes\ndescription: The engine's copy.\n", root: engine)
      write_skill('engine-only', "name: engine-only\ndescription: Ships with the engine.\n", root: engine)
      described_class.roots << fixtures << engine

      expect(described_class.find(:ticket_codes).path.to_s).to eq(File.join(fixtures, 'ticket-codes'))
      expect(described_class.find('engine-only').description).to eq('Ships with the engine.')
      expect(described_class.all.map(&:name)).to eq(%w[csv-report ticket-codes engine-only])
    end
  end

  describe '.find' do
    before { described_class.roots << fixtures }

    it 'raises SkillNotFoundError for a missing skill or a name that is not a folder name' do
      expect { described_class.find(:missing) }.to raise_error(RubyLLM::SkillNotFoundError, /No skill named missing/)
      expect { described_class.find('../skills/ticket-codes') }.to raise_error(RubyLLM::SkillNotFoundError)
    end
  end

  describe '.all' do
    it 'returns nothing when no root exists' do
      expect(described_class.all).to eq([])
    end

    it 'skips folders without a SKILL.md and raises for an invalid skill' do
      tmpdir.join('not-a-skill').mkpath
      write_skill('broken', "name: other\ndescription: Wrong name.\n")
      described_class.roots << tmpdir

      expect { described_class.all }.to raise_error(RubyLLM::InvalidSkillError, /match its folder name/)
    end
  end

  describe '#resolve_file' do
    let(:skill) { described_class.new(File.join(fixtures, 'ticket-codes')) }

    it 'returns files inside the skill folder' do
      expect(skill.resolve_file('references/FORMAT.md')).to eq(File.join(fixtures, 'ticket-codes/references/FORMAT.md'))
      expect(skill.resolve_file('./references//FORMAT.md')).to end_with('references/FORMAT.md')
    end

    it 'refuses paths that leave the folder' do
      ['../csv-report/SKILL.md', '/etc/passwd', 'references/../../csv-report/SKILL.md', 'C:/Windows'].each do |path|
        expect { skill.resolve_file(path) }.to raise_error(ArgumentError, /not a path inside the ticket-codes skill/)
      end
    end

    it 'refuses symbolic links that point outside the folder' do
      folder = write_skill('linked', "name: linked\ndescription: Links out.\n")
      File.write(tmpdir.join('secret.txt'), 'secret')
      File.symlink(tmpdir.join('secret.txt'), folder.join('secret.txt'))
      File.symlink(folder.join('SKILL.md'), folder.join('inside.md'))
      linked = described_class.new(folder)

      expect { linked.resolve_file('secret.txt') }.to raise_error(ArgumentError, /not a path inside/)
      expect(linked.resolve_file('inside.md')).to eq(folder.realpath.join('SKILL.md').to_s)
    end
  end
end
