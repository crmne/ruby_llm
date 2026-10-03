# frozen_string_literal: true

require 'json'
require 'tmpdir'

namespace :opentelemetry do
  desc 'Check RubyLLM traces against the official GenAI conventions (requires Weaver 0.26.1)'
  task :check do
    Dir.mktmpdir('ruby-llm-opentelemetry') do |directory|
      samples = File.join(directory, 'samples')
      FileUtils.mkdir_p(samples)
      Dir.glob('spec/ruby_llm/open_telemetry*_spec.rb').each do |spec|
        sh({ 'RUBYLLM_OTEL_SAMPLES' => samples }, 'bundle', 'exec', 'rspec', spec, '--format', 'progress')
      end
      telemetry = Dir.glob(File.join(samples, '*.json')).flat_map { |file| JSON.parse(File.read(file)) }
      abort 'No OpenTelemetry samples were recorded' if telemetry.empty?

      input = File.join(directory, 'samples.json')
      File.write(input, JSON.generate(telemetry))
      registry = File.join(directory, 'genai')
      sh 'git', 'init', '--quiet', registry
      sh 'git', '-C', registry, 'fetch', '--quiet', '--depth', '1',
         'https://github.com/open-telemetry/semantic-conventions-genai.git',
         'e07f4ebacb08f56db8c4c882d117720333fbca04'
      sh 'git', '-C', registry, 'checkout', '--quiet', '--detach', 'FETCH_HEAD'
      FileUtils.cp('conformance/opentelemetry/workflows.yaml', File.join(registry, 'model', 'ruby_llm.yaml'))
      sh ENV.fetch('WEAVER', 'weaver'), 'registry', 'live-check',
         '--registry', File.join(registry, 'model'), '--input-source', input,
         '--format', 'json', '--no-stream', '--output', File.join(directory, 'report')
      puts "Validated #{telemetry.size} spans against the GenAI registry."
    end
  end
end
