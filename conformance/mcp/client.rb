# frozen_string_literal: true

# Drives RubyLLM::MCP through one scenario of the official MCP conformance
# suite. The harness starts a scenario server, passes its URL as the last
# argument, names the scenario in MCP_CONFORMANCE_SCENARIO, and judges the
# requests it receives.

require 'bundler/setup'
require 'ruby_llm'

scenario = ENV.fetch('MCP_CONFORMANCE_SCENARIO')
url = ARGV.last
context = JSON.parse(ENV.fetch('MCP_CONFORMANCE_CONTEXT', '{}')).then { |data| data['context'] || data }
redirect_uri = 'http://localhost:0/callback'

RubyLLM.configure { |config| config.mcp_client_id = 'https://conformance-test.local/client-metadata.json' }

def oauth_settings(scenario, context)
  client = { client_id: context['client_id'], client_secret: context['client_secret'] }
  case scenario
  when 'auth/client-credentials-basic' then client.merge(grant: :client_credentials)
  when 'auth/client-credentials-jwt'
    { grant: :client_credentials, client_id: context['client_id'], private_key: context['private_key_pem'] }
  when 'auth/wif-jwt-bearer' then { assertion: context['valid_jwt'] }
  when 'auth/enterprise-managed-authorization'
    client.merge(identity_provider: { issuer: context['idp_issuer'], client_id: context['idp_client_id'],
                                      id_token: context['idp_id_token'] })
  else client
  end
end

settings = oauth_settings(scenario, context)
mcp = Class.new(RubyLLM::MCP) do
  url url
  oauth(**settings) if scenario.start_with?('auth/')
  before_input_request { |request| request.answer(confirmed: true) }
end.new

def authorize(mcp, redirect_uri)
  location = Faraday.get(mcp.authorization_url(redirect_uri:)).headers['location']
  mcp.authorize(URI.decode_www_form(URI(location).query.to_s).to_h)
end

MRTR_TOOLS = %i[test_mrtr_echo_state test_mrtr_unrelated test_mrtr_no_state test_mrtr_no_result_type].freeze

SCENARIOS = {
  'tools_call' => ->(mcp, _) { mcp.call(:add_numbers, a: 1, b: 2) },
  'sse-retry' => ->(mcp, _) { mcp.call(:test_reconnection) },
  'sep-2322-client-request-state' => ->(mcp, _) { MRTR_TOOLS.each { |name| mcp.call(name) } },
  'json-schema-2020-12-preservation' => lambda do |mcp, _|
    schema = mcp.send(:server_tools).find { |tool| tool['name'] == 'json_schema_2020_12_tool' }['inputSchema']
    mcp.call(:json_schema_echo, schema:)
  end,
  'http-standard-headers' => lambda do |mcp, _|
    mcp.call(mcp.tools.find { |tool| tool.name == 'test_headers' }&.name || mcp.tools.first.name)
    mcp.resource(mcp.resources.first.uri)
    mcp.prompt(mcp.prompts.first.name)
  end,
  'http-custom-headers' => lambda do |mcp, context|
    Array(context['toolCalls']).each { |call| mcp.call(call['name'], **call['arguments'].transform_keys(&:to_sym)) }
  end,
  'http-invalid-tool-headers' => ->(mcp, _) { mcp.call(:valid_tool, message: 'hello') },
  'auth/scope-step-up' => ->(mcp, _) { mcp.call(mcp.tools.first.name) }
}.freeze

def run(mcp, scenario, context)
  mcp.tools
  SCENARIOS[scenario]&.call(mcp, context)
end

attempts = 0
begin
  run(mcp, scenario, context)
rescue RubyLLM::UnauthorizedError, RubyLLM::ForbiddenError
  raise if (attempts += 1) > 2

  authorize(mcp, redirect_uri)
  retry
rescue RubyLLM::Error => e
  abort "#{scenario}: #{e.class}: #{e.message}"
end
