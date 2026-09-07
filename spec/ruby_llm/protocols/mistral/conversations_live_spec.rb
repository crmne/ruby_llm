# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Mistral::Conversations, :live do
  let(:chat) { RubyLLM.chat(model: model_for(:mistral), provider: :mistral, protocol: :conversations) }

  it 'searches the web with citations and replays hosted results in a stateless conversation' do
    chat.with_server_tools(:web_search)
        .with_instructions('Search once for the first request. Answer subsequent requests from the existing results.')
    response = chat.ask('Find the official Ruby 3.4.0 release announcement. Give its date and a citation.')
    expect(response.server_tool_calls).to include(have_attributes(name: 'web_search'))
    expect(response.citations).to include(have_attributes(url: a_string_including('ruby-lang.org')))
    expect(response.tokens.input).to be_positive
    expect(chat.ask('What version was that announcement for?').content).to include('3.4')
  end

  it 'fetches a public page through the web fetch alias' do
    response = chat.with_server_tools(:web_fetch).ask(
      'Open https://www.ruby-lang.org/en/news/2024/12/25/ruby-3-4-0-released/ with open_url. ' \
      'Which parser does that release make the default?'
    )
    expect(response.content).to match(/Prism/i)
    expect(response.server_tool_calls.map(&:raw)).to include(include('function' => 'open_url'))
  end

  it 'streams hosted Python execution with complete tool history and usage' do
    chunks = []
    response = chat.with_server_tools(:code_execution).ask('Use Python to multiply 37 by 19.') do |chunk|
      chunks << chunk
    end
    expect(chunks.filter_map(&:content).join).to eq(response.content)
    expect(response.content).to include('703')
    expect(response.server_tool_calls).to include(have_attributes(name: 'code_interpreter'))
    expect(response.tokens.server_tool_use).to include('code_interpreter' => 1)
    expect(response.tokens.output).to be_positive
    expect(chat.ask('What was the result?').content).to include('703')
  end

  it 'searches an uploaded document through the file search alias' do
    connection = chat.provider.connection
    library = connection.post('libraries', { name: 'RubyLLM file search integration test' }).body
    library_id = library.fetch('id')
    file = Faraday::Multipart::FilePart.new(
      StringIO.new('The fictional test project is codenamed saffron and has seven paper robots.'),
      'text/plain', 'facts.txt'
    )
    document = connection.post("libraries/#{library_id}/documents", { file: }) do |request|
      request.headers.delete('Content-Type')
    end.body
    Timeout.timeout(30) do
      loop do
        status = connection.get("libraries/#{library_id}/documents/#{document.fetch('id')}/status").body
        break if status['process_status'] == 'done'

        sleep 0.5
      end
    end
    response = chat.with_server_tools(file_search: { library_ids: [library_id] }).ask(
      'Search facts.txt in the library. What is the fictional project codename and how many paper robots does it have?'
    )
    expect(response.content).to match(/saffron/i)
    expect(response.content).to match(/seven|7/i)
    expect(response.server_tool_calls).to include(have_attributes(name: 'document_library'))
  ensure
    connection.delete("libraries/#{library_id}") if library_id
  end
end
