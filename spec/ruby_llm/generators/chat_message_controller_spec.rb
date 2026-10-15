# frozen_string_literal: true

require 'spec_helper'
require 'ferrum'
require 'generators/ruby_llm/chat_ui/chat_ui_generator'

RSpec.describe 'The chat UI message controller', :generator do # rubocop:disable RSpec/DescribeClass
  generator = RubyLLM::Generators::ChatUIGenerator
  fixtures = File.expand_path('../../fixtures/javascript', __dir__)

  let(:files) do
    {
      '/chat_message_controller.js' => File.read(File.join(generator.source_root,
                                                           'javascript/controllers/chat_message_controller.js')),
      '/marked.js' => File.read(File.join(fixtures, "marked-#{generator::MARKED_VERSION}.js")),
      '/dompurify.js' => File.read(File.join(fixtures, "dompurify-#{generator::DOMPURIFY_VERSION}.js")),
      '/stimulus.js' => <<~JS
        export class Controller {
          constructor(element) {
            this.element = element
            for (const name of this.constructor.targets) {
              Object.defineProperty(this, `${name}Target`, {
                get: () => element.querySelector(`[data-chat-message-target="${name}"]`)
              })
            }
          }
        }
      JS
    }
  end

  let(:browser) { Ferrum::Browser.new(headless: true, timeout: 10) }

  # Ferrum talks to Chrome over local HTTP, which no cassette should record.
  around do |example|
    cassette = VCR.eject_cassette
    WebMock.disable!
    VCR.turned_off(ignore_cassettes: true) { example.run }
  ensure
    WebMock.enable!
    VCR.insert_cassette(cassette.name) if cassette
  end

  after { browser.quit }

  def open_message(source, streaming: false)
    files['/'] = <<~HTML
      <script type="importmap">
        { "imports": { "@hotwired/stimulus": "/stimulus.js", "marked": "/marked.js", "dompurify": "/dompurify.js" } }
      </script>
      <div id="message_1" data-controller="chat-message"#{' data-streaming' if streaming}>
        <div id="message_1_stream" data-chat-message-target="source">#{source}</div>
        <div data-chat-message-target="output"></div>
      </div>
      <script type="module">
        import ChatMessageController from "/chat_message_controller.js"
        window.controller = new ChatMessageController(document.getElementById("message_1"))
        window.controller.connect()
      </script>
    HTML
    serve_files
    browser.go_to('http://chat.test/')
    wait_for { browser.evaluate('window.controller !== undefined') }
  end

  def serve_files
    browser.network.intercept
    browser.on(:request) do |request|
      body = files[URI(request.url).path]
      next request.abort unless body

      type = request.url.end_with?('.js') ? 'text/javascript' : 'text/html'
      request.respond(body:, responseHeaders: { 'content-type' => type, 'content-length' => body.bytesize.to_s })
    end
  end

  def output_html
    browser.evaluate("document.querySelector('[data-chat-message-target=output]').innerHTML")
  end

  def wait_for(timeout: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    sleep 0.05 until yield || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
  end

  it 'renders Markdown through DOMPurify, so markup in a reply stays inert' do
    attack = ERB::Util.html_escape(%(**bold** <img src=x onerror="window.pwned = 1"> <script>window.pwned = 2</script>))
    open_message(attack)
    wait_for { output_html.include?('<strong>') }

    expect(output_html).to include('<strong>bold</strong>')
    expect(output_html).not_to include('onerror')
    expect(output_html).not_to include('<script')
    expect(browser.evaluate('window.pwned')).to be_nil
    expect(browser.evaluate("document.getElementById('message_1_stream').hidden")).to be(true)
  end

  it 'orders streamed chunks and shows only the run without gaps' do
    open_message('<span data-seq="2">b</span><span data-seq="1">a</span><span data-seq="4">d</span>', streaming: true)
    wait_for { output_html.include?('ab') }
    expect(output_html).to include('ab')
    expect(output_html).not_to include('d')

    browser.execute(<<~JS)
      const chunk = document.createElement("span")
      chunk.dataset.seq = "3"
      chunk.textContent = "c"
      document.getElementById("message_1_stream").append(chunk)
    JS
    wait_for { output_html.include?('abcd') }
    expect(output_html).to include('abcd')
  end

  it 'drops a repeated chunk' do
    open_message('<span data-seq="1">a</span><span data-seq="1">a</span><span data-seq="2">b</span>', streaming: true)
    wait_for { output_html.include?('ab') }
    expect(output_html).to include('ab')
    expect(output_html).not_to include('aa')
  end
end
