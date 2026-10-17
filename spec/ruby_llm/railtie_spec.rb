# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'tmpdir'

RSpec.describe 'RubyLLM::Railtie' do
  describe 'booting a Rails app with skills' do
    let(:root) { Dir.mktmpdir('ruby_llm_skills_app') }

    after { FileUtils.remove_entry(root) }

    def write_skill(name, under: root)
      folder = File.join(under, 'app/skills', name)
      FileUtils.mkdir_p(File.join(folder, 'scripts'))
      File.write(File.join(folder, 'SKILL.md'), "---\nname: #{name}\ndescription: Bills an order.\n---\n")
      File.write(File.join(folder, 'scripts/build_invoice.rb'), "File.write('invoice.txt', 'total: 42')\n")
    end

    def boot(eager_load:, engine: nil)
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
          config.logger = Logger.new(nil)
          config.secret_key_base = 'x' * 64
          config.load_defaults Rails::VERSION::STRING.to_f
        end
        begin
          Rails.application.initialize!
          print RubyLLM::Skill.all.map(&:name).join(',')
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
  end
end
