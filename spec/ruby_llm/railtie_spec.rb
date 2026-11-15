# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'tmpdir'

RSpec.describe 'RubyLLM::Railtie' do
  describe 'booting a Rails app with an import map' do
    let(:root) { Dir.mktmpdir('ruby_llm_importmap_app') }

    after { FileUtils.remove_entry(root) }

    def imports
      script = <<~RUBY
        require 'bundler/setup'
        require 'logger'
        require 'rails'
        require 'action_controller/railtie'
        require 'propshaft'
        require 'importmap-rails'
        require 'ruby_llm'
        require 'ruby_llm/railtie'
        class ImportmapApp < Rails::Application
          config.root = #{root.inspect}
          config.eager_load = false
          config.logger = Logger.new(nil)
          config.secret_key_base = 'x' * 64
          config.load_defaults Rails::VERSION::STRING.to_f
        end
        Rails.application.initialize!
        imports = JSON.parse(Rails.application.importmap.to_json(resolver: ActionController::Base.helpers))['imports']
        assets = %w[chat_message_controller marked dompurify].map { |name| Rails.application.assets.load_path.find("ruby_llm/\#{name}.js")&.logical_path.to_s }
        print JSON.generate(imports: imports, assets: assets)
      RUBY
      stdout, stderr, = Open3.capture3(RbConfig.ruby, '-I', File.expand_path('../../lib', __dir__), '-e', script,
                                       chdir: root)
      raise stderr if stdout.empty?

      JSON.parse(stdout)
    end

    it "pins the chat UI's Stimulus controller and its libraries to the gem's assets" do
      booted = imports

      expect(booted['assets']).to eq(%w[ruby_llm/chat_message_controller.js ruby_llm/marked.js ruby_llm/dompurify.js])
      expect(booted['imports']['ruby_llm/chat_message_controller'])
        .to match(%r{\A/assets/ruby_llm/chat_message_controller-\h+\.js\z})
      expect(booted['imports']['marked']).to match(%r{\A/assets/ruby_llm/marked-\h+\.js\z})
      expect(booted['imports']['dompurify']).to match(%r{\A/assets/ruby_llm/dompurify-\h+\.js\z})
    end

    it "lets the app's own pins win" do
      FileUtils.mkdir_p(File.join(root, 'config'))
      File.write(File.join(root, 'config/importmap.rb'), %(pin "marked", to: "https://cdn.example/marked.js"\n))

      booted = imports

      expect(booted['imports']['marked']).to eq('https://cdn.example/marked.js')
      expect(booted['imports']['dompurify']).to match(%r{\A/assets/ruby_llm/dompurify-\h+\.js\z})
    end
  end

  describe 'booting a Rails app with skills' do
    let(:root) { Dir.mktmpdir('ruby_llm_skills_app') }

    after { FileUtils.remove_entry(root) }

    def write_skill(name, under: root)
      folder = File.join(under, 'app/skills', name)
      write_skill_folder(folder, File.basename(name))
    end

    def write_skill_folder(folder, name)
      FileUtils.mkdir_p(File.join(folder, 'scripts'))
      File.write(File.join(folder, 'SKILL.md'), "---\nname: #{name}\ndescription: Bills an order.\n---\n")
      File.write(File.join(folder, 'scripts/build_invoice.rb'), "File.write('invoice.txt', 'total: 42')\n")
    end

    def write_ruby(path, source)
      file = File.join(root, 'app/skills', path)
      FileUtils.mkdir_p(File.dirname(file))
      File.write(file, source)
    end

    def boot(eager_load:, engine: nil, reloading: false, then_run: 'RubyLLM::Skill.all.map(&:name).join(",")')
      script = <<~RUBY
        require 'bundler/setup'
        require 'logger'
        require 'rails'
        require 'action_controller/railtie'
        require 'ruby_llm'
        require 'ruby_llm/railtie'
        #{"require #{engine.inspect}" if engine}
        class SkillsApp < Rails::Application
          config.root = #{root.inspect}
          config.eager_load = #{eager_load}
          config.enable_reloading = #{reloading}
          config.logger = Logger.new(nil)
          config.secret_key_base = 'x' * 64
          config.load_defaults Rails::VERSION::STRING.to_f
        end
        begin
          Rails.application.initialize!
          print(#{then_run})
        rescue StandardError, ScriptError => e
          print e.class
        end
      RUBY
      stdout, = Open3.capture3(RbConfig.ruby, '-I', File.expand_path('../../lib', __dir__), '-e', script, chdir: root)
      stdout
    end

    it 'does not load a skill script when it eager loads' do
      write_skill('invoices')

      expect(boot(eager_load: true)).to eq('invoices')
      expect(File.exist?(File.join(root, 'invoice.txt'))).to be(false)
    end

    it 'does not read a hyphenated skill folder as a namespace' do
      write_skill('pdf-processing')

      expect(boot(eager_load: false)).to eq('pdf-processing')
    end

    it 'does not load the scripts of a skill root an engine registers' do
      engine_root = Dir.mktmpdir('ruby_llm_skills_engine')
      write_skill('refunds', under: engine_root)

      engine = File.join(engine_root, 'lib/billing_engine.rb')
      FileUtils.mkdir_p(File.dirname(engine))
      File.write(engine, <<~RUBY)
        class BillingEngine < Rails::Engine
          initializer 'billing_engine.skills', before: 'ruby_llm.skills' do
            RubyLLM::Skill.roots << root.join('app/skills')
          end
        end
      RUBY

      expect(boot(eager_load: true, engine: engine)).to eq('refunds')
    ensure
      FileUtils.remove_entry(engine_root)
    end

    it 'autoloads the Ruby classes an app keeps in app/skills next to its skills' do
      write_skill('invoices')
      write_ruby('summarizer.rb', "class Summarizer; def self.call = 'summary'; end\n")
      write_ruby('research/web_search.rb', "module Research; class WebSearch; def self.call = 'results'; end; end\n")

      loaded = '[Summarizer.call, Research::WebSearch.call, RubyLLM::Skill.all.map(&:name)].join(",")'

      [false, true].each do |eager_load|
        expect(boot(eager_load: eager_load, then_run: loaded)).to eq('summary,results,invoices')
      end
      expect(File.exist?(File.join(root, 'invoice.txt'))).to be(false)
    end

    it 'keeps a skill folder nested inside a Ruby namespace out of the autoloader' do
      write_ruby('billing/ledger.rb', "module Billing; class Ledger; def self.call = 'ledger'; end; end\n")
      write_skill_folder(File.join(root, 'app/skills/billing/pdf-refunds'), 'pdf-refunds')

      expect(boot(eager_load: true, then_run: 'Billing::Ledger.call')).to eq('ledger')
      expect(File.exist?(File.join(root, 'invoice.txt'))).to be(false)
    end

    it 'keeps a skill folder that is a symbolic link out of the autoloader' do
      linked = Dir.mktmpdir('ruby_llm_linked_skills')
      write_skill_folder(File.join(linked, 'pdf-processing'), 'pdf-processing')
      write_skill_folder(File.join(linked, 'pdf-refunds'), 'pdf-refunds')
      write_ruby('summarizer.rb', "class Summarizer; def self.call = 'summary'; end\n")
      FileUtils.mkdir_p(File.join(root, 'app/skills/billing'))
      File.symlink(File.join(linked, 'pdf-processing'), File.join(root, 'app/skills/pdf-processing'))
      File.symlink(File.join(linked, 'pdf-refunds'), File.join(root, 'app/skills/billing/pdf-refunds'))

      expect(boot(eager_load: true, then_run: '[Summarizer.call, RubyLLM::Skill.all.map(&:name)].join(",")'))
        .to eq('summary,pdf-processing')
      expect(File.exist?(File.join(root, 'invoice.txt'))).to be(false)
    ensure
      FileUtils.remove_entry(linked)
    end

    it 'keeps a skill added after boot out of the autoloader when the app reloads' do
      write_ruby('summarizer.rb', "class Summarizer; def self.call = 'summary'; end\n")
      File.write(File.join(root, 'after_boot.rb'), <<~RUBY)
        folder = File.join(Rails.root, 'app/skills/pdf-processing')
        FileUtils.mkdir_p(File.join(folder, 'scripts'))
        File.write(File.join(folder, 'SKILL.md'), "---\\nname: pdf-processing\\ndescription: Reads PDFs.\\n---\\n")
        File.write(File.join(folder, 'scripts/build_invoice.rb'), "File.write('invoice.txt', 'total: 42')\\n")
        Rails.application.reloader.reload!
        Rails.autoloaders.main.eager_load
        [Summarizer.call, RubyLLM::Skill.all.map(&:name)].join(',')
      RUBY

      expect(boot(eager_load: false, reloading: true, then_run: "eval(File.read('after_boot.rb'))"))
        .to eq('summary,pdf-processing')
      expect(File.exist?(File.join(root, 'invoice.txt'))).to be(false)
    end
  end
end
