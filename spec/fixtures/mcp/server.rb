# frozen_string_literal: true

# A small MCP server for specs. It speaks 2026-07-28 by default and only the
# legacy initialize handshake when MCP_ERA=legacy.

require 'json'

LEGACY = ENV['MCP_ERA'] == 'legacy'
$stdout.sync = true

TOOLS = [
  {
    name: 'echo',
    description: 'Echoes the text back',
    inputSchema: { type: 'object', properties: { text: { type: 'string' } }, required: ['text'] },
    annotations: { readOnlyHint: true }
  },
  {
    name: 'add',
    description: 'Adds two numbers',
    inputSchema: {
      type: 'object',
      properties: { a: { type: 'number' }, b: { type: 'number' } },
      required: %w[a b]
    }
  },
  { name: 'fail', description: 'Always fails', inputSchema: { type: 'object' } },
  { name: 'picture', description: 'Returns a picture', inputSchema: { type: 'object' } },
  { name: 'slow', description: 'Reports progress', inputSchema: { type: 'object' } },
  { name: 'wait', description: 'Never answers', inputSchema: { type: 'object' } },
  {
    name: 'delete_everything', description: 'Deletes everything', inputSchema: { type: 'object' },
    annotations: { readOnlyHint: false, destructiveHint: true, openWorldHint: false }
  }
].freeze

PIXEL = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='

RESOURCES = {
  'file:///project/README.md' => { mimeType: 'text/markdown', text: "# Spec Project\n" },
  'file:///project/pixel.png' => { mimeType: 'image/png', blob: PIXEL }
}.freeze

PROMPT = {
  name: 'code_review', description: 'Reviews code',
  arguments: [{ name: 'code', description: 'The code to review', required: true }, { name: 'language' }]
}.freeze

def read_resource(uri)
  resource = RESOURCES[uri] || { mimeType: 'text/plain', text: "Contents of #{uri}" }
  { contents: [{ uri: }.merge(resource)] }
end

def get_prompt(arguments)
  request = "Review this #{arguments['language']} code:\n#{arguments['code']}"
  { description: 'Reviews code', messages: [
    { role: 'user', content: { type: 'text', text: request } },
    { role: 'assistant', content: { type: 'text', text: 'Happy to. What should I focus on?' } },
    { role: 'user', content: { type: 'text', text: 'Security.' } }
  ] }
end

def complete(params)
  values = %w[ruby rust python].select { |value| value.start_with?(params.dig('argument', 'value')) }
  values = values.map { |value| "#{value} (#{params.dig('context', 'arguments', 'code')})" } if params['context']
  { completion: { values:, total: values.size, hasMore: false } }
end

def reply(id, result: nil, error: nil)
  puts JSON.generate({ jsonrpc: '2.0', id:, result:, error: }.compact)
end

def tools_page(cursor)
  cursor ? { tools: TOOLS.drop(2) } : { tools: TOOLS.take(2), nextCursor: 'page-2' }
end

def call_tool(params)
  arguments = params.fetch('arguments', {})
  case params['name']
  when 'echo' then { content: [{ type: 'text', text: arguments['text'] }] }
  when 'add'
    sum = arguments['a'] + arguments['b']
    { content: [{ type: 'text', text: sum.to_s }], structuredContent: { sum: } }
  when 'fail' then { content: [{ type: 'text', text: 'Something broke' }], isError: true }
  when 'picture'
    { content: [{ type: 'text', text: 'Here it is' }, { type: 'image', data: PIXEL, mimeType: 'image/png' },
                { type: 'resource_link', uri: 'file:///pixel.png', name: 'pixel.png' }] }
  when 'delete_everything' then { content: [{ type: 'text', text: 'Gone' }] }
  when 'slow' then { content: [{ type: 'text', text: 'Finished' }] }
  else raise ArgumentError, "Unknown tool: #{params['name']}"
  end
end

initialized = false
cancelled = []

def notify(method, params)
  puts JSON.generate({ jsonrpc: '2.0', method:, params: })
end

$stdin.each_line do |line|
  message = JSON.parse(line)
  id = message['id']
  params = message.fetch('params', {})

  case message['method']
  when 'server/discover'
    if LEGACY
      reply(id, error: { code: -32_601, message: 'Method not found' })
    else
      reply(id, result: {
              resultType: 'complete', supportedVersions: ['2026-07-28'],
              capabilities: { tools: {} }, instructions: 'A server for specs.',
              _meta: { 'io.modelcontextprotocol/serverInfo' => { name: 'spec-server', version: '1.0.0' } }
            })
    end
  when 'initialize'
    initialized = true
    reply(id, result: { protocolVersion: '2025-06-18', capabilities: { tools: {} },
                        serverInfo: { name: 'spec-server', version: '0.9.0' } })
  when 'notifications/initialized'
    nil
  when 'tools/list'
    next reply(id, error: { code: -32_600, message: 'Not initialized' }) if LEGACY && !initialized

    reply(id, result: tools_page(params['cursor']))
  when 'tools/call'
    case params['name']
    when 'wait' then next
    when 'slow'
      token = params.dig('_meta', 'progressToken')
      if token
        [1, 2].each { |step| notify('notifications/progress', { progressToken: token, progress: step, total: 2 }) }
      end
    end
    reply(id, result: call_tool(params))
  when 'notifications/cancelled' then cancelled << params['requestId']
  when 'spec/cancelled' then reply(id, result: { cancelled: })
  when 'resources/list'
    resources = RESOURCES.map { |uri, resource| { uri:, name: File.basename(uri), mimeType: resource[:mimeType] } }
    reply(id, result: { resources: })
  when 'resources/read' then reply(id, result: read_resource(params['uri']))
  when 'resources/templates/list'
    reply(id, result: { resourceTemplates: [{ uriTemplate: 'file:///project/{+path}', name: 'Project files' }] })
  when 'prompts/list' then reply(id, result: { prompts: [PROMPT] })
  when 'prompts/get' then reply(id, result: get_prompt(params.fetch('arguments', {})))
  when 'completion/complete' then reply(id, result: complete(params))
  when 'meta/echo'
    reply(id, result: { meta: params['_meta'] })
  else
    reply(id, error: { code: -32_601, message: 'Method not found' }) if id
  end
end
