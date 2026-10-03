# frozen_string_literal: true

require 'opentelemetry-sdk'

RSpec.shared_context 'with OpenTelemetry tracing' do
  let(:exporter) { OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new }
  let(:provider) { OpenTelemetry::SDK::Trace::TracerProvider.new(sampler: OpenTelemetry::SDK::Trace::Samplers::ALWAYS_ON) }

  before do
    provider.add_span_processor(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter))
    allow(OpenTelemetry).to receive(:tracer_provider).and_return(provider)
    RubyLLM::OpenTelemetry.enable
  end

  after do
    if ENV['RUBYLLM_OTEL_SAMPLES']
      samples = spans.select { |span| span.instrumentation_scope.name == 'ruby_llm' }.map do |span|
        { span: { name: span.name, kind: span.kind,
                  attributes: span.attributes.to_h.map { |name, value| { name:, value: } },
                  status: { code: span.status.code == OpenTelemetry::Trace::Status::ERROR ? 'error' : 'unset', message: span.status.description.to_s } } }
      end
      File.write(File.join(ENV.fetch('RUBYLLM_OTEL_SAMPLES'), "#{SecureRandom.hex(8)}.json"), JSON.generate(samples))
    end
  ensure
    RubyLLM::OpenTelemetry.disable
    provider.shutdown
  end

  def spans
    exporter.finished_spans
  end
end
