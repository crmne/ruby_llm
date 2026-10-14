# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'rbconfig'
require 'stringio'
require 'time'

# Runs mutineer over RubyLLM. Plain-Ruby code runs against the plain specs
# booted from spec_helper; Rails integration code runs against the Rails specs,
# serially, booted from rails_helper. A full run splits the library into shards,
# keeps each shard's report under tmp/mutineer, and skips a shard whose source
# and spec tree are unchanged since its report was written.
module MutationTesting
  STATE_DIR = 'tmp/mutineer'
  UNIT = 'ruby_llm-mutineer'
  CASSETTE_DIRS = %w[spec/fixtures/vcr_cassettes spec/fixtures/websocket_cassettes].freeze
  RAILS_SOURCES = %w[lib/ruby_llm/active_record/**/*.rb lib/ruby_llm/railtie.rb].freeze
  GLOB_FLAGS = File::FNM_PATHNAME | File::FNM_EXTGLOB

  # A source belongs to the first shard with a matching glob. Each shard pays
  # for one coverage capture of its pass's whole spec suite, so shards stay
  # large; the last one in each pass catches files added since.
  SHARDS = [
    ['rails-chat', :rails, %w[lib/ruby_llm/active_record/{chat_methods,run_claims}.rb]],
    ['rails', :rails, RAILS_SOURCES],
    ['core-a-b', :plain, %w[lib/ruby_llm.rb lib/ruby_llm/[ab]*.rb]],
    ['chat', :plain, %w[lib/ruby_llm/c*.rb lib/ruby_llm/chat/**/*.rb]],
    ['core-d-l', :plain, %w[lib/ruby_llm/[d-l]*.rb lib/ruby_llm/{evaluation,judge}/**/*.rb]],
    ['mcp', :plain, %w[lib/ruby_llm/mcp.rb lib/ruby_llm/mcp/**/*.rb]],
    ['core-m-o', :plain, %w[lib/ruby_llm/[m-o]*.rb lib/ruby_llm/{model,models,open_telemetry}/**/*.rb]],
    ['core-p-r', :plain, %w[lib/ruby_llm/[p-r]*.rb lib/ruby_llm/{protocol,prompt,request_shape}/**/*.rb]],
    ['core-s-z', :plain,
     %w[lib/ruby_llm/[s-z]*.rb lib/ruby_llm/{support,tools,transport,transcription}/**/*.rb]],
    ['protocols-anthropic', :plain, %w[lib/ruby_llm/protocols/anthropic/**/*.rb]],
    ['protocols-google', :plain, %w[lib/ruby_llm/protocols/{gemini,vertexai,interactions}/**/*.rb]],
    ['protocols-aws', :plain, %w[lib/ruby_llm/protocols/{converse,bedrock,invoke_model}/**/*.rb]],
    ['protocols-openai', :plain, %w[
      lib/ruby_llm/protocols/*.rb
      lib/ruby_llm/protocols/{chat_completions,responses,openai,openrouter,xai}/**/*.rb
      lib/ruby_llm/protocols/{gpustack,deepseek,perplexity,system_one,files}/**/*.rb
    ]],
    ['protocols-other', :plain, %w[lib/ruby_llm/protocols/**/*.rb]],
    ['providers', :plain, %w[lib/ruby_llm/providers/**/*.rb]],
    ['other', :plain, %w[lib/ruby_llm/**/*.rb]]
  ].freeze

  # One mutineer configuration: which specs run, how the suite boots, and the
  # options that keep it correct.
  Pass = Data.define(:name, :boot, :options) do
    def rails? = name == :rails

    def specs(root)
      Dir.glob('spec/**/*_spec.rb', base: root).sort.reject do |path|
        path.start_with?('spec/dummy/', 'spec/ruby_llm/generators/') ||
          File.read(File.join(root, path)).include?('rails_helper') != rails?
      end
    end
  end

  PASSES = {
    plain: Pass.new(name: :plain, boot: 'spec/spec_helper.rb', options: []),
    rails: Pass.new(name: :rails, boot: 'spec/rails_helper.rb', options: %w[--jobs 1 --strategy redefine])
  }.freeze

  # A group of sources run by one mutineer invocation.
  Shard = Data.define(:name, :pass, :sources)

  module_function

  def pass_for(source)
    RAILS_SOURCES.any? { |glob| File.fnmatch?(glob, source, GLOB_FLAGS) } ? PASSES[:rails] : PASSES[:plain]
  end

  def sources(root)
    (Dir.glob('lib/ruby_llm.rb', base: root) + Dir.glob('lib/ruby_llm/**/*.rb', base: root))
      .reject { |path| File.basename(path).start_with?('mutineer_mutant') }
      .sort
  end

  def shards(root)
    assigned = sources(root).group_by do |source|
      SHARDS.find do |_, pass, globs|
        pass == pass_for(source).name && globs.any? do |g|
          File.fnmatch?(g, source, GLOB_FLAGS)
        end
      end
    end
    SHARDS.filter_map do |entry|
      files = assigned[entry]
      Shard.new(name: entry[0], pass: PASSES.fetch(entry[1]), sources: files) if files
    end
  end

  def state_dir(root) = File.join(root, STATE_DIR)

  def mutineer_version
    Gem.loaded_specs['mutineer']&.version&.to_s
  end

  # The environment every mutant runs in. CI=1 makes VCR replay cassettes
  # without recording, so a mutant never reaches a provider API.
  def environment(pass, label)
    {
      'CI' => '1',
      'SKIP_COVERAGE' => '1',
      'SPEC_OPTS' => '--tag ~generator',
      'TEST_ENV_NUMBER' => "-mutineer-#{label}",
      'RUBYOPT' => [ENV.fetch('RUBYOPT', nil), '-W0'].compact.join(' '),
      'RAILS_ENV' => ('test' if pass.rails?)
    }
  end

  def command(pass, sources, specs, cache_dir:, extra: [])
    [
      RbConfig.ruby, '-rbundler/setup', Gem.bin_path('mutineer', 'mutineer'), 'run', *sources,
      *specs.flat_map { |spec| ['--test', spec] },
      '--framework', 'rspec', '--boot', pass.boot, '--cache-dir', cache_dir,
      *pass.options, *extra
    ]
  end

  def git(root, *)
    output, status = Open3.capture2('git', '-C', root, *, err: File::NULL)
    output.strip if status.success?
  end
end

require_relative 'mutation_testing/fingerprint'
require_relative 'mutation_testing/cassette_lock'
require_relative 'mutation_testing/report'
require_relative 'mutation_testing/spec_selection'
require_relative 'mutation_testing/full_run'
require_relative 'mutation_testing/background'
require_relative 'mutation_testing/cli'
