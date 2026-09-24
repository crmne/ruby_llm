# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'
require 'open3'
require 'tmpdir'
require 'yaml'

RSpec.describe 'Versioned documentation site', type: :task do
  let(:root) { File.expand_path('../..', __dir__) }
  let(:site) { Dir.mktmpdir('rubyllm-docs-spec') }

  after do
    FileUtils.remove_entry(site)
  end

  def write_page(relative, content = 'page')
    path = File.join(site, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
    path
  end

  def run_script(name, *args)
    output, status = Open3.capture2e(RbConfig.ruby, File.join(root, 'docs/bin', name), *args)
    expect(status.success?).to be(true), output
  end

  def html(relative)
    Nokogiri::HTML(File.read(File.join(site, relative)))
  end

  describe 'release selection' do
    around { |example| GitEnvironment.without { example.run } }

    before do
      commands = [
        %w[init --quiet],
        ['-c', 'user.name=Docs Spec', '-c', 'user.email=docs@example.test',
         'commit', '--quiet', '--allow-empty', '-m', 'Release fixture']
      ]
      commands.each do |args|
        output, status = Open3.capture2e('git', '-C', site, *args)
        raise output unless status.success?
      end
    end

    it 'selects the newest stable and 1.x tags by version, excluding prereleases and unrelated tags' do
      %w[1.16.0 v1.17.0 v2.9.0 v2.10.0 v3.0.0.rc1 v3.0.0-beta.1 backup].each do |tag|
        system('git', '-C', site, 'tag', tag, exception: true)
      end
      output, status = Open3.capture2e(RbConfig.ruby, File.join(root, 'docs/bin/release_tags.rb'), site)

      expect(status.success?).to be(true), output
      expect(output.split).to eq(%w[v2.10.0 v1.17.0])
    end

    it 'fails rather than substituting main when release tags are missing' do
      output, status = Open3.capture2e(RbConfig.ruby, File.join(root, 'docs/bin/release_tags.rb'), site)

      expect(status.success?).to be(false)
      expect(output).to include('requires stable release tags and a 1.x release tag')
    end
  end

  describe 'redirects' do
    before do
      write_page('index.html', 'stable home')
      write_page('chat/index.html', 'stable chat')
      write_page('chat.md', 'stable chat markdown')
      write_page('api/RubyLLM/Chat.html', 'stable API')
      write_page('next/index.html', 'next home')
      write_page('next/chat/index.html', 'next chat')
      write_page('next/chat.md', 'next chat markdown')
      write_page('next/api/RubyLLM/Chat.html', 'next API')
      write_page('next/api/RubyLLM/Chat.md', 'next API markdown')
      write_page('next/llms.txt', 'next index')
      write_page('v1/index.html', 'legacy home')
      write_page('v1/chat/index.html', 'legacy chat')
      write_page('v1/rails/index.html', 'legacy Rails')
      write_page('404.html', 'not found')
      write_page('v1/404.html', 'old not found')
      write_page('llms.txt', 'stable index')
      write_page('robots.txt', "User-agent: *\nSitemap: https://rubyllm.com/sitemap.xml\n")
    end

    it 'keeps independent stable and next pages, API references, and machine-readable content' do
      run_script('build_version_redirects.rb', site)

      expect(File.read(File.join(site, 'chat/index.html'))).to eq('stable chat')
      expect(File.read(File.join(site, 'next/chat/index.html'))).to eq('next chat')
      expect(File.read(File.join(site, 'next/api/RubyLLM/Chat.html'))).to eq('next API')
      expect(File.read(File.join(site, 'next/llms.txt'))).to eq('next index')
      expect(File.read(File.join(site, 'next/chat.md'))).to eq('next chat markdown')
      expect(File.read(File.join(site, 'next/api/RubyLLM/Chat.md'))).to eq('next API markdown')
      expect(File).not_to exist(File.join(site, 'next/v1'))
    end

    it 'preserves legacy-only routes without replacing stable pages or error pages' do
      run_script('build_version_redirects.rb', site)

      expect(html('rails/index.html').at_css('a')['href']).to eq('/v1/rails/')
      expect(html('rails/index.html').at_css('script').text).to include('window.location.search',
                                                                        'window.location.hash')
      expect(html('rails/index.html').at_css('meta[name=robots]')['content']).to eq('noindex,follow')
      expect(File.read(File.join(site, 'v1/chat/index.html'))).to eq('legacy chat')
      expect(File.read(File.join(site, '404.html'))).to eq('not found')
    end

    it 'exposes the next and legacy sitemaps without copying the stable machine-readable index' do
      run_script('build_version_redirects.rb', site)

      expect(File.read(File.join(site, 'robots.txt'))).to include(
        'https://rubyllm.com/sitemap.xml', 'https://rubyllm.com/next/sitemap.xml', 'https://rubyllm.com/v1/sitemap.xml'
      )
      expect(File.read(File.join(site, 'llms.txt'))).to eq('stable index')
    end

    it 'supports a Pages base path for legacy section redirects and sitemap discovery' do
      run_script('build_version_redirects.rb', site, '/ruby_llm')

      expect(html('rails/index.html').at_css('link[rel=canonical]')['href']).to eq('https://rubyllm.com/ruby_llm/v1/rails/')
      expect(File.read(File.join(site, 'robots.txt'))).to include('https://rubyllm.com/ruby_llm/next/sitemap.xml')
    end
  end

  describe 'version selector' do
    it 'labels the working tree as unreleased without pinning release versions' do
      versions = YAML.load_file(File.join(root, 'docs/_data/versions.yml'))

      expect(versions['current']).to eq('next')
      expect(versions['items']).to include(include('id' => 'stable', 'url' => '/'))
      expect(versions['items']).to include(include('id' => 'next', 'url' => '/next/', 'title' => 'Next (unreleased)'))
      expect(versions['items']).to include(include('id' => 'v1', 'url' => '/v1/'))
    end

    it 'labels each channel from its selected tags and uses site-wide URLs within every version' do
      { 'stable' => '2.10.0 (stable)', 'next' => 'Next (unreleased)', 'v1' => '1.17.0' }.each do |current, label|
        path = write_page('versions.yml', File.read(File.join(root, 'docs/_data/versions.yml')))
        run_script('prepare_versions.rb', path, current, '/ruby_llm', 'v2.10.0', '1.17.0')
        versions = YAML.load_file(path)

        expect(versions['current']).to eq(label)
        expect(versions['items'].pluck('url')).to eq([
                                                       '/ruby_llm/', '/ruby_llm/next/', '/ruby_llm/v1/',
                                                       'https://github.com/crmne/ruby_llm/releases'
                                                     ])
      end
    end
  end

  describe 'versioned metadata' do
    it 'keeps canonicals and API discovery within the selected version while retaining the live registry URL' do
      pages = [double(data: { 'canonical_url' => 'https://rubyllm.com/available-models/' }),
               double(data: { 'canonical_url' => 'https://example.com/reference/' })]
      config = { 'url' => 'https://rubyllm.com', 'baseurl' => '/ruby_llm/next', 'jekyll_vitepress' => {
        'llms' => { 'details' => 'https://rubyllm.com/api/index.md https://rubyllm.com/models.json' }
      } }
      jekyll_site = double(config:, pages:, collections: {},
                           data: { 'versions' => { 'current' => 'Next (unreleased)' } })
      hooks = stub_const('Jekyll::Hooks', double)
      allow(hooks).to receive(:register) do |*_args, **_options, &callback|
        callback.call(jekyll_site)
      end

      load File.join(root, 'docs/_plugins/versioned_docs.rb')

      expect(pages.first.data['canonical_url']).to eq('/available-models/')
      expect(pages.last.data['canonical_url']).to eq('https://example.com/reference/')
      expect(config['docs_unreleased']).to be(true)
      expect(config.dig('jekyll_vitepress', 'llms')).to include(
        'description' => 'Developer documentation for RubyLLM Next (unreleased).',
        'details' => 'https://rubyllm.com/ruby_llm/next/api/index.md https://rubyllm.com/models.json'
      )
    end
  end

  describe 'deployment' do
    it 'builds from main on release publication with full history for the release archives' do
      workflow = YAML.load_file(File.join(root, '.github/workflows/docs.yml'))
      events = workflow.fetch(true)
      checkout = workflow.fetch('jobs').fetch('build').fetch('steps').find { |step| step['name'] == 'Checkout' }

      expect(events.fetch('release')).to eq('types' => ['published'])
      expect(checkout.fetch('with')).to include('ref' => 'main', 'fetch-depth' => 0)
    end
  end

  describe 'API documentation' do
    it 'keeps guide links and canonical URLs in the selected version' do
      path = 'next/api/RubyLLM/Chat.html'
      write_page(path, <<~HTML)
        <html><head><title>Chat</title></head><body>
        <a href="https://rubyllm.com/">Guides</a>
        <a href="https://rubyllm.com/upgrading/">Upgrading</a>
        <a href="https://github.com/crmne/ruby_llm">Source</a>
        </body></html>
      HTML
      run_script('postprocess_api_seo.rb', File.join(site, 'next/api'), 'https://rubyllm.com/ruby_llm/next')

      expect(html(path).at_css('link[rel=canonical]')['href'])
        .to eq('https://rubyllm.com/ruby_llm/next/api/RubyLLM/Chat.html')
      expect(html(path).at_css('meta[property="og:image"]')['content'])
        .to eq('https://rubyllm.com/ruby_llm/next/assets/images/social-card.jpg')
      expect(html(path).css('a').map { |link| link['href'] }).to eq([
                                                                      'https://rubyllm.com/ruby_llm/next/',
                                                                      'https://rubyllm.com/ruby_llm/next/upgrading/',
                                                                      'https://github.com/crmne/ruby_llm'
                                                                    ])
    end
  end

  describe 'frozen 1.x assets' do
    it 'keeps assets and copied Markdown inside the selected documentation version' do
      write_page('_config.yml', '{}')
      write_page('_includes/head.html', '')
      write_page('_advanced/rails.md', File.read(File.join(root, 'spec/fixtures/docs/one_x_rails.md')))
      write_page('_includes/head_custom.html', <<~HTML)
        <link rel="icon" href="/assets/images/logo.svg">
        <script defer src="/assets/js/copy-page-markdown.js"></script>
        <script src="https://example.com/analytics.js"></script>
      HTML
      write_page('_layouts/default.html', <<~HTML)
        <button data-markdown-base="{{ site.markdown_source_base_url | escape }}"
                data-markdown-path="{{ page.path | escape }}">Copy page</button>
      HTML

      run_script('prepare_one_x_docs.rb', site)

      config = YAML.load_file(File.join(site, '_config.yml'))
      expect(config.dig('jekyll_vitepress', 'seo', 'image')).to eq(
        'path' => '/assets/images/social-card.jpg',
        'alt' => 'RubyLLM',
        'width' => 1200,
        'height' => 630
      )
      expect(File.binread(File.join(site, 'assets/images/social-card.jpg')))
        .to eq(File.binread(File.join(root, 'docs/assets/images/social-card.jpg')))
      head = File.read(File.join(site, '_includes/head_custom.html'))
      expect(head).to include("{{ '/assets/js/copy-page-markdown.js' | relative_url }}")
      expect(head).to include("{{ '/assets/images/logo.svg' | relative_url }}")
      expect(head).to include('src="https://example.com/analytics.js"')
      layout = File.read(File.join(site, '_layouts/default.html'))
      expect(layout).to include("{{ '/' | relative_url | escape }}")
      expect(layout).to include("{% if page.url == '/' %}index.md{% else %}")
      expect(layout).to include("page.url | append: '.md' | replace: '/.md', '.md'")
      expect(layout).not_to include('site.markdown_source_base_url', 'page.path')
    end
  end
end
