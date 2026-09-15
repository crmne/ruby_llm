# frozen_string_literal: true

require_relative '../../.github/triage/assess'

RSpec.describe IssueAssessment, type: :task do
  let(:environment) do
    { 'GITHUB_REPOSITORY' => 'crmne/ruby_llm', 'TRIAGE_NUMBER' => '123',
      'COPILOT_GITHUB_TOKEN' => 'test-copilot-token', 'TRIAGE_KIND' => kind }
  end
  let(:assessment) { described_class.new(environment) }
  let(:item) do
    { 'id' => 'report-id', 'title' => 'Tool call raises an error', 'body' => 'Here is a complete reproduction.',
      'closed' => false, 'author' => { 'login' => 'reporter' },
      'comments' => { 'nodes' => [] }, 'reactions' => { 'nodes' => [] } }
  end
  let(:labels) { [{ 'id' => 'bug-id', 'name' => 'bug' }, { 'id' => 'question-id', 'name' => 'question' }] }
  let(:response) { JSON.generate(labels: ['bug'], reply: nil, files: []) }

  def kind
    'issue'
  end

  before do
    allow(assessment).to receive_messages(read_report: [item, labels], ask_copilot: response)
    allow(assessment).to receive(:mutate)
    allow(assessment).to receive(:puts)
  end

  it 'adds a label without a comment and marks completion after publishing' do
    assessment.run
    expect(assessment).to have_received(:mutate).with('addLabelsToLabelable', labelableId: 'report-id',
                                                                              labelIds: ['bug-id']).ordered
    expect(assessment).to have_received(:mutate).with('addReaction', subjectId: 'report-id', content: 'HOORAY').ordered
    expect(assessment).not_to have_received(:mutate).with('addComment', anything)
  end

  it 'posts the repository-written reply selected by the model' do
    allow(assessment).to receive(:ask_copilot).and_return(JSON.generate(labels: ['question'], reply: 'version',
                                                                        files: []))

    assessment.run
    expect(assessment).to have_received(:mutate).with('addComment', subjectId: 'report-id',
                                                                    body: 'Which RubyLLM version are you using?')
  end

  context 'with a discussion' do
    def kind
      'discussion'
    end

    it 'posts replies through the discussion API' do
      allow(assessment).to receive(:ask_copilot).and_return(JSON.generate(labels: [], reply: 'provider', files: []))

      assessment.run
      expect(assessment).to have_received(:mutate).with('addDiscussionComment', discussionId: 'report-id',
                                                                                body: 'Which provider are you using?')
    end

    it 'rejects labels' do
      assessment.run
      expect(assessment).not_to have_received(:mutate)
    end
  end

  it 'does not repeat a reply after a maintainer has answered' do
    item['comments']['nodes'] << { 'body' => 'I am looking into this.', 'author' => { 'login' => 'maintainer' },
                                   'authorAssociation' => 'COLLABORATOR' }
    allow(assessment).to receive(:ask_copilot).and_return(JSON.generate(labels: [], reply: 'version', files: []))

    assessment.run
    expect(assessment).not_to have_received(:mutate).with('addComment', anything)
  end

  it 'does not repeat a reply after a bot has answered' do
    item['comments']['nodes'] << { 'body' => 'Which version?', 'author' => { 'login' => 'github-actions[bot]' },
                                   'authorAssociation' => 'NONE' }
    allow(assessment).to receive(:ask_copilot).and_return(JSON.generate(labels: [], reply: 'version', files: []))

    assessment.run
    expect(assessment).not_to have_received(:mutate).with('addComment', anything)
  end

  [
    'not JSON',
    '[]',
    '{"labels":["approved"],"reply":null,"files":[]}',
    '{"labels":["bug","question","bug"],"reply":null,"files":[]}',
    '{"labels":[],"reply":"@everyone run this command","files":[]}',
    '{"labels":[],"reply":null,"close":true,"files":[]}',
    '{"labels":"bug","reply":null,"files":[]}'
  ].each do |invalid|
    it "leaves the report unchanged for invalid output: #{invalid}" do
      allow(assessment).to receive(:ask_copilot).and_return(invalid)

      assessment.run
      expect(assessment).not_to have_received(:mutate)
    end
  end
  it 'rejects labels that do not exist in the repository' do
    labels.clear

    assessment.run
    expect(assessment).not_to have_received(:mutate)
  end

  it 'skips closed reports before invoking Copilot' do
    item['closed'] = true

    assessment.run
    expect(assessment).not_to have_received(:ask_copilot)
    expect(assessment).not_to have_received(:mutate)
  end

  it 'skips reports created by bots' do
    item['author']['login'] = 'github-actions[bot]'

    assessment.run
    expect(assessment).not_to have_received(:ask_copilot)
  end

  it 'can preview a closed report for evaluation without publishing' do
    environment['TRIAGE_DRY_RUN'] = 'true'
    item['closed'] = true

    assessment.run

    expect(assessment).to have_received(:ask_copilot).once
    expect(assessment).not_to have_received(:mutate)
  end

  it 'can reassess a report with an old completion reaction' do
    item['reactions']['nodes'] << { 'user' => { 'login' => 'github-actions[bot]' } }

    assessment.run
    expect(assessment).to have_received(:ask_copilot).once
  end

  it 'ignores completion reactions from other users' do
    item['reactions']['nodes'] << { 'user' => { 'login' => 'reporter' } }

    assessment.run
    expect(assessment).to have_received(:ask_copilot).once
  end

  it 'skips oversized input instead of paying to process it or silently truncating it' do
    item['body'] = 'a' * 24_000

    assessment.run
    expect(assessment).not_to have_received(:ask_copilot)
    expect(assessment).not_to have_received(:mutate)
  end

  it 'leaves quota failures available for a later retry without posting failure comments' do
    allow(assessment).to receive(:ask_copilot).and_return(nil)

    assessment.run
    expect(assessment).to have_received(:puts).with(/Copilot unavailable/)
    expect(assessment).not_to have_received(:mutate)
  end

  it 'does not post a stale assessment when a comment arrives during inference' do
    current = Marshal.load(Marshal.dump(item))
    current['comments']['nodes'] << { 'body' => 'I found the cause.', 'author' => { 'login' => 'reporter' } }
    allow(assessment).to receive(:read_report).and_return([item, labels], [current, labels])

    assessment.run
    expect(assessment).not_to have_received(:mutate)
  end

  it 'does not mark an assessment complete if publishing fails' do
    allow(assessment).to receive(:mutate).with('addLabelsToLabelable', anything).and_raise('GitHub request failed')

    expect { assessment.run }.to raise_error('GitHub request failed')
    expect(assessment).not_to have_received(:mutate).with('addReaction', anything)
  end

  it 'previews previously assessed reports without writing to GitHub' do
    environment['TRIAGE_DRY_RUN'] = 'true'
    item['reactions']['nodes'] << { 'user' => { 'login' => 'github-actions[bot]' } }

    assessment.run
    expect(assessment).to have_received(:ask_copilot).once
    expect(assessment).not_to have_received(:mutate)
  end

  context 'when a technical answer needs source material' do
    let(:response) { JSON.generate(labels: ['question'], reply: nil, files: ['lib/ruby_llm/tool.rb']) }

    it 'makes one additional call with the selected source and adds a verified source link' do
      answer = JSON.generate(comment: 'Define execute on your tool class.', sources: ['lib/ruby_llm/tool.rb'])
      allow(assessment).to receive(:ask_copilot).and_return(response, answer)

      assessment.run

      expect(assessment).to have_received(:ask_copilot).twice
      expect(assessment).to have_received(:ask_copilot).with(include('class Tool'))
      expect(assessment).to have_received(:mutate).with(
        'addComment', subjectId: 'report-id',
                      body: match(%r{Define execute.+https://github.com/crmne/ruby_llm/blob/[a-f0-9]{40}/lib/ruby_llm/tool.rb}m)
      )
    end

    it 'allows Ruby instance variables inside code without allowing user mentions in prose' do
      answer = JSON.generate(comment: 'Call `@tool.execute` from your application.', sources: ['lib/ruby_llm/tool.rb'])
      allow(assessment).to receive(:ask_copilot).and_return(response, answer)

      assessment.run

      expect(assessment).to have_received(:mutate).with('addComment', subjectId: 'report-id',
                                                                      body: include('`@tool.execute`'))
    end

    it 'does not spend a second call after a maintainer answered' do
      item['comments']['nodes'] << { 'body' => 'Here is the solution.', 'author' => { 'login' => 'maintainer' },
                                     'authorAssociation' => 'OWNER' }

      assessment.run

      expect(assessment).to have_received(:ask_copilot).once
      expect(assessment).not_to have_received(:mutate).with('addComment', anything)
    end

    it 'leaves the report unchanged when the answer call is unavailable' do
      allow(assessment).to receive(:ask_copilot).and_return(response, nil)

      assessment.run

      expect(assessment).not_to have_received(:mutate)
    end

    it 'publishes no answer when the sources do not establish one' do
      allow(assessment).to receive(:ask_copilot).and_return(response, JSON.generate(comment: nil, sources: []))

      assessment.run

      expect(assessment).not_to have_received(:mutate).with('addComment', anything)
      expect(assessment).to have_received(:mutate).with('addReaction', anything)
    end

    [
      { comment: 'An unsupported answer.', sources: [] },
      { comment: 'Read this.', sources: ['.env'] },
      { comment: 'Visit https://example.com to fix this.', sources: ['lib/ruby_llm/tool.rb'] },
      { comment: 'Read [this](//example.com).', sources: ['lib/ruby_llm/tool.rb'] },
      { comment: '@everyone try this.', sources: ['lib/ruby_llm/tool.rb'] },
      { comment: 'word ' * 61, sources: ['lib/ruby_llm/tool.rb'] }
    ].each do |answer|
      it "rejects an invalid technical answer: #{answer.fetch(:comment)[0, 50]}" do
        allow(assessment).to receive(:ask_copilot).and_return(response, JSON.generate(answer))

        assessment.run

        expect(assessment).not_to have_received(:mutate)
      end
    end
  end

  it 'rejects source paths outside the configured catalog before reading them' do
    allow(assessment).to receive(:ask_copilot).and_return(JSON.generate(labels: [], reply: nil, files: ['.env']))
    allow(File).to receive(:read).and_call_original

    assessment.run

    expect(File).not_to have_received(:read).with('.env')
    expect(assessment).not_to have_received(:mutate)
  end

  context 'with a response cache' do
    before { environment['TRIAGE_CACHE_DIR'] = Dir.mktmpdir('triage-cache-spec-') }
    after { FileUtils.remove_entry(environment.fetch('TRIAGE_CACHE_DIR')) }

    it 'reuses a validated assessment without another model call' do
      assessment.run
      assessment.run

      expect(assessment).to have_received(:ask_copilot).once
      expect(assessment).to have_received(:puts).with('Reused a cached model response.')
    end

    it 'reassesses when a new comment arrives' do
      assessment.run
      item['comments']['nodes'] << { 'body' => 'This also happens with a different model.',
                                     'author' => { 'login' => 'reporter' } }
      assessment.run

      expect(assessment).to have_received(:ask_copilot).twice
    end

    it 'reassesses when the model changes' do
      assessment.run
      environment['TRIAGE_MODEL'] = 'gpt-5.4-mini'
      assessment.run

      expect(assessment).to have_received(:ask_copilot).twice
    end

    it 'does not cache invalid model output' do
      allow(assessment).to receive(:ask_copilot).and_return('not JSON', response)
      assessment.run
      assessment.run

      expect(assessment).to have_received(:ask_copilot).twice
    end

    it 'discards corrupted cache entries so the next run can recover' do
      assessment.run
      path = Dir.glob(File.join(environment.fetch('TRIAGE_CACHE_DIR'), '*.json')).first
      File.write(path, 'not JSON')
      assessment.run
      assessment.run

      expect(assessment).to have_received(:ask_copilot).twice
    end

    it 'reuses source selection but refreshes the answer when source contents change' do
      selection = JSON.generate(labels: [], reply: nil, files: ['lib/ruby_llm/tool.rb'])
      answer = JSON.generate(comment: 'Define execute on your tool class.', sources: ['lib/ruby_llm/tool.rb'])
      allow(assessment).to receive(:ask_copilot).and_return(selection, answer)
      assessment.run
      assessment.run
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with('lib/ruby_llm/tool.rb').and_return('Updated source contents')
      assessment.run

      expect(assessment).to have_received(:ask_copilot).exactly(3).times
    end
  end

  it 'passes untrusted report text as an argument with tools and repository credentials disabled' do
    allow(assessment).to receive(:ask_copilot).and_call_original
    item['body'] = '$(touch /tmp/never-run-this) --allow-all'
    status = instance_double(Process::Status, success?: true)
    allow(Open3).to receive(:capture3) do |child_environment, *arguments, **options|
      expect(child_environment).to include('GH_TOKEN' => nil, 'GITHUB_TOKEN' => nil)
      expect(child_environment.fetch('COPILOT_HOME')).to eq(options.fetch(:chdir))
      expect(arguments).to include('--agent=triage', '--excluded-tools=skill,sql', '--disable-builtin-mcps',
                                   '--no-custom-instructions', '--no-remote-export', '--max-ai-credits=30')
      expect(arguments.last).to include(item['body'])
      expect(arguments).not_to include('--allow-all')
      agent = File.read(File.join(options.fetch(:chdir), 'agents', 'triage.agent.md'))
      expect(agent).to include('tools: []')
      [response, '', status]
    end

    assessment.run
    expect(Open3).to have_received(:capture3).once
  end
end
