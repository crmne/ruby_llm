# frozen_string_literal: true

require 'spec_helper'
require 'yaml'

RSpec.describe 'llms.txt discovery', type: :task do
  let(:root) { File.expand_path('../..', __dir__) }
  let(:areas) { YAML.load_file(File.join(root, 'docs/_data/llms_areas.yml')) }

  before do
    stub_const('Jekyll::Hooks', double(register: nil))
    llms = Module.new do
      def self.canonical_url(item) = "https://rubyllm.com/next#{item.url}"
    end
    copy_page = Module.new do
      def self.page_enabled?(item) = item.data['jekyll_vitepress'] != false
    end
    stub_const('Jekyll::VitePressTheme::LLMS', llms)
    stub_const('Jekyll::VitePressTheme::CopyPage', copy_page)
    load File.join(root, 'docs/_plugins/llms_discovery.rb')
  end

  def doc(url, path, collection: nil, data: {})
    collection &&= double(label: collection)
    double(url:, path:, collection:, data:)
  end

  it 'links each page to its Markdown twin' do
    expect(LLMSDiscovery.markdown_url(doc('/chat/', '_getting_started/chat.md')))
      .to eq('https://rubyllm.com/next/chat.md')
    expect(LLMSDiscovery.markdown_url(doc('/', 'index.md'))).to eq('https://rubyllm.com/next/index.md')
    expect(LLMSDiscovery.markdown_url(doc('/models/', 'models.md', data: { 'jekyll_vitepress' => false })))
      .to eq('https://rubyllm.com/next/models/')
  end

  it 'sorts pages into areas by name, then collection, and leaves the home page and catalogs out' do
    pages = [doc('/', 'index.md'),
             doc('/agents/', '_getting_started/agents.md', collection: 'getting_started'),
             doc('/rails/', '_getting_started/rails.md', collection: 'getting_started'),
             doc('/upgrading/', '_reference/upgrading.md', collection: 'reference'),
             doc('/available-models/', '_reference/available-models.md', collection: 'reference',
                                                                         data: { 'layout' => 'models' }),
             doc('/chat/', '_getting_started/chat.md', collection: 'getting_started')]
    site = double(data: { 'llms_areas' => areas })

    sorted = LLMSDiscovery.areas_for(site, [{ items: pages }]).to_h { |area| [area['id'], area['items'].map(&:url)] }

    expect(sorted).to eq('tools-and-agents' => ['/agents/'], 'rails' => ['/rails/'],
                         'reference' => ['/upgrading/'], 'core' => ['/chat/'])
  end
end
