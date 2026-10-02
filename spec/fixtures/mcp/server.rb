# frozen_string_literal: true

# A small MCP server for specs. It speaks 2026-07-28 by default and only the
# legacy initialize handshake when MCP_ERA=legacy. It announces changes to
# its lists and resources unless MCP_CHANGES=none, and never watches
# resources whose URI starts with unwatched:.

require 'json'

LEGACY = %w[legacy discover_without_modern].include?(ENV.fetch('MCP_ERA', nil))
DISCOVER_WITHOUT_MODERN = ENV['MCP_ERA'] == 'discover_without_modern'
$stdout.sync = true

SUBSCRIPTION_ID = 'io.modelcontextprotocol/subscriptionId'
CAPABILITIES = if ENV['MCP_CHANGES'] == 'none'
                 { tools: {} }
               else
                 { tools: { listChanged: true }, prompts: { listChanged: true },
                   resources: { listChanged: true, subscribe: true } }
               end
LISTS = {
  'notifications/tools/list_changed' => 'toolsListChanged',
  'notifications/prompts/list_changed' => 'promptsListChanged',
  'notifications/resources/list_changed' => 'resourcesListChanged'
}.freeze

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
    },
    _meta: { 'com.example/owner' => 'math' }
  },
  { name: 'fail', description: 'Always fails', inputSchema: { type: 'object' } },
  { name: 'picture', description: 'Returns a picture', inputSchema: { type: 'object' } },
  { name: 'slow', description: 'Reports progress', inputSchema: { type: 'object' } },
  { name: 'wait', description: 'Never answers', inputSchema: { type: 'object' } },
  { name: 'deploy', description: 'Asks where to deploy', inputSchema: { type: 'object' } },
  { name: 'connect', description: 'Asks the user to connect an account', inputSchema: { type: 'object' } },
  {
    name: 'delete_everything', description: 'Deletes everything', inputSchema: { type: 'object' },
    annotations: { readOnlyHint: false, destructiveHint: true, openWorldHint: false }
  }
].freeze

UI = 'io.modelcontextprotocol/ui'

UI_TOOLS = [
  {
    name: 'forecast', description: 'Shows the forecast',
    inputSchema: { type: 'object', properties: { city: { type: 'string' } } },
    _meta: { ui: { resourceUri: 'ui://spec/forecast' } }
  },
  {
    name: 'refresh_forecast', description: 'Refreshes the forecast view', inputSchema: { type: 'object' },
    _meta: { ui: { resourceUri: 'ui://spec/forecast', visibility: ['app'] } }
  }
].freeze

FORECAST_VIEW = {
  mimeType: 'text/html;profile=mcp-app', text: '<!DOCTYPE html><html><body>Forecast</body></html>',
  _meta: { ui: { csp: { connectDomains: ['https://api.example.com'] }, prefersBorder: true } }
}.freeze

PIXEL = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='

RESOURCES = {
  'file:///project/README.md' => {
    mimeType: 'text/markdown', text: "# Spec Project\n", _meta: { 'com.example/etag' => 'v2' }
  },
  'file:///project/pixel.png' => { mimeType: 'image/png', blob: PIXEL }
}.freeze

PROMPT = {
  name: 'code_review', description: 'Reviews code',
  arguments: [{ name: 'code', description: 'The code to review', required: true }, { name: 'language' }]
}.freeze

def read_resource(uri)
  resource = RESOURCES[uri] || (FORECAST_VIEW if uri == 'ui://spec/forecast') ||
             { mimeType: 'text/plain', text: "Contents of #{uri}" }
  { contents: [{ uri: }.merge(resource)] }
end

ENVIRONMENT_FORM = {
  method: 'elicitation/create',
  params: {
    mode: 'form', message: 'Which environment?',
    requestedSchema: {
      type: 'object', required: ['environment'],
      properties: {
        environment: { type: 'string', title: 'Environment', enum: %w[staging production], default: 'staging' }
      }
    }
  }
}.freeze

CONNECT_URL = {
  method: 'elicitation/create',
  params: { mode: 'url', message: 'Connect your account', url: 'https://example.com/connect' }
}.freeze

TASKS = 'io.modelcontextprotocol/tasks'

TASK_TOOLS = %w[report approve_report broken_report endless_report].map do |name|
  { name:, description: "Runs #{name.tr('_', ' ')} in the background", inputSchema: { type: 'object' } }
end.freeze

CONFIRM_FORM = {
  method: 'elicitation/create',
  params: {
    mode: 'form', message: 'Publish the report?',
    requestedSchema: { type: 'object', properties: { approved: { type: 'boolean' } }, required: ['approved'] }
  }
}.freeze

def task_state(id, status, **fields)
  { taskId: id, status:, createdAt: '2026-10-02T10:00:00Z', lastUpdatedAt: '2026-10-02T10:00:00Z',
    ttlMs: 60_000, pollIntervalMs: 10 }.merge(fields)
end

def create_task(tasks, name)
  id = "task-#{tasks.size + 1}"
  tasks[id] = { tool: name, polls: 0, answers: {} }
  task_state(id, 'working', statusMessage: 'Queued').merge(resultType: 'task')
end

def report_state(task, id)
  return task_state(id, 'working', statusMessage: 'Rendering') if task[:polls] < 2

  task_state(id, 'completed', result: { content: [{ type: 'text', text: 'Report ready' }],
                                        structuredContent: { pages: 2 } })
end

def approval_state(task, id)
  answer = task[:answers]['confirm']
  return task_state(id, 'input_required', inputRequests: { 'confirm' => CONFIRM_FORM }) unless answer

  text = "Approved: #{answer.dig('content', 'approved')}"
  task_state(id, 'completed', result: { content: [{ type: 'text', text: }] })
end

def poll_task(task, id)
  task[:polls] += 1
  return task_state(id, 'cancelled', statusMessage: 'Cancelled by the client') if task[:cancelled]

  case task[:tool]
  when 'report' then report_state(task, id)
  when 'approve_report' then approval_state(task, id)
  when 'broken_report'
    task_state(id, 'failed', statusMessage: 'Renderer crashed', error: { code: -32_603, message: 'Renderer crashed' })
  else task_state(id, 'working', statusMessage: 'Still rendering')
  end
end

CLIENT_ASKS = {
  'ping-1' => 'ping', 'roots-1' => 'roots/list', 'sample-1' => 'sampling/createMessage',
  'elicit-1' => 'elicitation/create'
}.freeze

# Asks the client what servers of the 2025 revisions may ask mid-call,
# and waits for every answer before it answers the call.
def ask_client
  CLIENT_ASKS.each { |id, method| puts JSON.generate({ jsonrpc: '2.0', id:, method:, params: {} }) }
  answers = {}
  while answers.size < CLIENT_ASKS.size && (line = $stdin.gets)
    answer = JSON.parse(line)
    answers[answer['id']] = answer['result'] || answer['error'] if CLIENT_ASKS.key?(answer['id'])
  end
  { content: [{ type: 'text', text: JSON.generate(answers) }] }
end

def input_required(key, request)
  { resultType: 'input_required', inputRequests: { key => request }, requestState: "#{key}-state" }
end

def deploy(params)
  answer = params.dig('inputResponses', 'environment')
  return input_required('environment', ENVIRONMENT_FORM) unless answer && params['requestState'] == 'environment-state'
  return { content: [{ type: 'text', text: 'Deploy cancelled' }] } unless answer['action'] == 'accept'

  { content: [{ type: 'text', text: "Deployed to #{answer.dig('content', 'environment')}" }] }
end

def connect(params)
  answer = params.dig('inputResponses', 'connect')
  return input_required('connect', CONNECT_URL) unless answer

  { content: [{ type: 'text', text: 'Connected' }] }
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

def tools_page(cursor, tools, extensions)
  return { tools: tools.take(2), nextCursor: 'page-2' } unless cursor

  { tools: tools.drop(2) + (extensions.key?(UI) ? UI_TOOLS : []) + (extensions.key?(TASKS) ? TASK_TOOLS : []) }
end

def forecast(arguments)
  city = arguments['city'] || 'Rome'
  { content: [{ type: 'text', text: "Sunny in #{city}" }], structuredContent: { city:, temperature: 24 },
    _meta: { 'com.example/station' => 'spec' } }
end

def call_tool(params)
  arguments = params.fetch('arguments', {})
  case params['name']
  when 'echo' then { content: [{ type: 'text', text: arguments['text'] }] }
  when 'add'
    sum = arguments['a'] + arguments['b']
    { content: [{ type: 'text', text: sum.to_s }], structuredContent: { sum: }, _meta: { 'com.example/exact' => true } }
  when 'fail' then { content: [{ type: 'text', text: 'Something broke' }], isError: true }
  when 'picture'
    { content: [{ type: 'text', text: 'Here it is' }, { type: 'image', data: PIXEL, mimeType: 'image/png' },
                { type: 'resource_link', uri: 'file:///pixel.png', name: 'pixel.png' }] }
  when 'delete_everything' then { content: [{ type: 'text', text: 'Gone' }] }
  when 'forecast' then forecast(arguments)
  when 'refresh_forecast' then { content: [{ type: 'text', text: 'Refreshed' }], structuredContent: { fresh: true } }
  when 'slow' then { content: [{ type: 'text', text: 'Finished' }] }
  when 'deploy' then deploy(params)
  when 'connect' then connect(params)
  else raise ArgumentError, "Unknown tool: #{params['name']}"
  end
end

initialized = false
cancelled = []
tools = TOOLS.dup
subscriptions = {}
watched = []
handshake_extensions = {}
tasks = {}

def notify(method, params)
  puts JSON.generate({ jsonrpc: '2.0', method:, params: })
end

def wants?(filter, method, params)
  return Array(filter['resourceSubscriptions']).include?(params['uri']) if method == 'notifications/resources/updated'
  return Array(filter['taskIds']).include?(params['taskId']) if method == 'notifications/tasks'

  filter[LISTS.fetch(method)] == true
end

# Servers that predate subscriptions announce every change, and resource
# updates for the URIs subscribed with resources/subscribe.
def announce(subscriptions, watched, method, params = {})
  if LEGACY
    notify(method, params) unless method == 'notifications/resources/updated' && !watched.include?(params['uri'])
  else
    subscriptions.each do |id, filter|
      notify(method, params.merge('_meta' => { SUBSCRIPTION_ID => id })) if wants?(filter, method, params)
    end
  end
end

def listen(subscriptions, id, filter, tasks)
  watched = Array(filter['resourceSubscriptions']).reject { |uri| uri.start_with?('unwatched:') }
  followed = Array(filter['taskIds']) & tasks.keys
  honored = filter.except('resourceSubscriptions', 'taskIds')
  honored['resourceSubscriptions'] = watched if watched.any?
  honored['taskIds'] = followed if followed.any?
  notify('notifications/subscriptions/acknowledged', { _meta: { SUBSCRIPTION_ID => id }, notifications: honored })
  return close_subscription(id) if honored.empty?

  subscriptions[id] = honored
end

def close_subscription(id)
  reply(id, result: { resultType: 'complete', _meta: { SUBSCRIPTION_ID => id } })
end

LOG_LEVELS = %w[debug info notice warning error critical alert emergency].freeze

def log(requested, level, data)
  return unless requested && LOG_LEVELS.index(level) >= LOG_LEVELS.index(requested)

  notify('notifications/message', { level:, logger: 'echo', data: })
end

$stdin.each_line do |line|
  message = JSON.parse(line)
  id = message['id']
  params = message.fetch('params', {})

  case message['method']
  when 'server/discover'
    if DISCOVER_WITHOUT_MODERN
      reply(id, result: { resultType: 'complete', supportedVersions: ['2025-11-25'], capabilities: { tools: {} } })
    elsif LEGACY
      reply(id, error: { code: -32_601, message: 'Method not found' })
    else
      reply(id, result: {
              resultType: 'complete', supportedVersions: ['2026-07-28'],
              capabilities: CAPABILITIES, instructions: 'A server for specs.',
              _meta: { 'io.modelcontextprotocol/serverInfo' => { name: 'spec-server', version: '1.0.0' } }
            })
    end
  when 'initialize'
    initialized = true
    handshake_extensions = params.dig('capabilities', 'extensions') || {}
    reply(id, result: { protocolVersion: '2025-06-18', capabilities: CAPABILITIES,
                        serverInfo: { name: 'spec-server', version: '0.9.0' } })
  when 'notifications/initialized'
    nil
  when 'ping' then reply(id, result: {})
  when 'tools/list'
    next reply(id, error: { code: -32_600, message: 'Not initialized' }) if LEGACY && !initialized

    extensions = params.dig('_meta', 'io.modelcontextprotocol/clientCapabilities', 'extensions')
    reply(id, result: tools_page(params['cursor'], tools, extensions || handshake_extensions))
  when 'spec/remove_tool'
    tools = tools.reject { |tool| tool[:name] == params['name'] }
    reply(id, result: {})
  when 'spec/change_tools'
    tools += [{ name: "extra_#{tools.size}", description: 'Added at runtime', inputSchema: { type: 'object' } }]
    announce(subscriptions, watched, 'notifications/tools/list_changed')
    reply(id, result: {})
  when 'subscriptions/listen'
    next reply(id, error: { code: -32_601, message: 'Method not found' }) if LEGACY

    listen(subscriptions, id, params.fetch('notifications', {}), tasks)
  when 'resources/subscribe', 'resources/unsubscribe'
    watched.delete(params['uri'])
    watched << params['uri'] if message['method'] == 'resources/subscribe'
    reply(id, result: {})
  when 'spec/announce'
    announce(subscriptions, watched, params['method'], params.fetch('params', {}))
    reply(id, result: {})
  when 'spec/announce_later'
    Thread.new do
      sleep 0.2
      announce(subscriptions, watched, params['method'], params.fetch('params', {}))
    end
    reply(id, result: {})
  when 'spec/end_subscriptions'
    subscriptions.each_key { |subscription| close_subscription(subscription) }.clear
    reply(id, result: {})
  when 'spec/cancel_subscriptions'
    subscriptions.each_key { |subscription| notify('notifications/cancelled', { requestId: subscription }) }.clear
    reply(id, result: {})
  when 'spec/subscriptions' then reply(id, result: { subscriptions:, watched: })
  when 'spec/exit' then exit
  when 'tools/call'
    if (TOOLS - tools).any? { |tool| tool[:name] == params['name'] }
      next reply(id, error: { code: -32_602, message: "Unknown tool: #{params['name']}" })
    end

    case params['name']
    when 'wait' then next
    when 'ask_client' then next reply(id, result: ask_client)
    when 'echo'
      level = params.dig('_meta', 'io.modelcontextprotocol/logLevel')
      log(level, 'debug', 'Echoing')
      log(level, 'warning', { 'slow' => true })
    when 'slow'
      token = params.dig('_meta', 'progressToken')
      if token
        [1, 2].each { |step| notify('notifications/progress', { progressToken: token, progress: step, total: 2 }) }
      end
    when *TASK_TOOLS.map { |tool| tool[:name] } then next reply(id, result: create_task(tasks, params['name']))
    end
    reply(id, result: call_tool(params))
  when 'tasks/get'
    task = tasks[params['taskId']]
    next reply(id, error: { code: -32_602, message: 'Task not found' }) unless task

    reply(id, result: poll_task(task, params['taskId']).merge(resultType: 'complete'))
  when 'tasks/update'
    tasks.fetch(params['taskId'])[:answers].merge!(params['inputResponses'])
    reply(id, result: { resultType: 'complete' })
  when 'tasks/cancel'
    tasks.fetch(params['taskId'])[:cancelled] = true
    reply(id, result: { resultType: 'complete' })
  when 'notifications/cancelled'
    subscriptions.delete(params['requestId'])
    cancelled << params['requestId']
  when 'spec/cancelled' then reply(id, result: { cancelled: })
  when 'spec/tasks'
    reply(id, result: { cancelled: tasks.select { |_, task| task[:cancelled] }.keys,
                        polls: tasks.transform_values { |task| task[:polls] } })
  when 'spec/stall' then $stdout.write('{"jsonrpc":')
  when 'resources/list'
    resources = RESOURCES.map do |uri, resource|
      { uri:, name: File.basename(uri), mimeType: resource[:mimeType], _meta: { 'com.example/listed' => true } }
    end
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
