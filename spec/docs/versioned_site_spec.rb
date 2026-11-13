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

  describe 'finishing the assembled site' do
    def finish_site
      docs = File.join(root, 'docs')
      env = { 'VITEPRESS_DOCS' => docs, 'VITEPRESS_SITE' => site }
      output, status = Open3.capture2e(env, RbConfig.ruby, File.join(docs, 'bin/finish_site.rb'))
      expect(status.success?).to be(true), output
    end

    before do
      write_page('robots.txt', "User-agent: *\nAllow: /\nDisallow: /*.md$\n\nSitemap: https://rubyllm.com/sitemap.xml\n")
    end

    it 'lets AI agents fetch the Markdown twins that search engines skip' do
      finish_site
      groups = File.read(File.join(site, 'robots.txt')).split(/\n{2,}/)
      ai_group = groups.find { |group| group.include?('User-agent: ClaudeBot') }

      expect(groups.first).to include('User-agent: *', 'Disallow: /*.md$')
      expect(ai_group).to include('User-agent: GPTBot', 'User-agent: PerplexityBot', 'Allow: /')
      expect(ai_group).not_to include('Disallow')
    end

    it 'publishes the model registry and the IndexNow key' do
      finish_site

      expect(File.read(File.join(site, 'models.json'))).to eq(File.read(File.join(root, 'lib/ruby_llm/models.json')))
      expect(Dir.children(site)).to include(match(/\A\h{32}\.txt\z/))
    end
  end

  describe 'versions' do
    let(:config) { YAML.load_file(File.join(root, 'docs/_config.yml')) }

    it 'publishes main at /next/ and keeps the newest 1.x, with its old URLs, at /v1/' do
      versions = config.dig('jekyll_vitepress', 'versions')

      expect(versions['next']).to be(true)
      expect(versions['keep']).to eq([{ 'major' => 1, 'redirect_missing' => true }])
    end

    it 'adds only the changelog to the versions the build fills in' do
      versions = YAML.load_file(File.join(root, 'docs/_data/versions.yml'))

      expect(versions['items']).to eq([{ 'id' => 'changelog', 'title' => 'Changelog',
                                         'url' => 'https://github.com/crmne/ruby_llm/releases',
                                         'external' => true }])
    end

    it 'builds every release with the plugins the current docs use' do
      overlay = config.dig('jekyll_vitepress', 'versions', 'overlay')

      overlay.each { |path| expect(File).to exist(File.join(root, 'docs', path)) }
      expect(overlay).to include('_plugins/versioned_docs.rb', '_plugins/social_cards.rb')
    end
  end

  describe 'versioned metadata' do
    before do
      stub_const('Jekyll::Hooks', double(register: nil))
      load File.join(root, 'docs/_plugins/versioned_docs.rb')
    end

    def rendered_page(output, channel:, theme: 'just-the-docs', title: 'RubyLLM')
      site = double(config: { 'title' => title, 'docs_channel' => channel, 'theme' => theme })
      Struct.new(:site, :output_ext, :output).new(site, '.html', output)
    end

    it 'names the version in templates and llms.txt, and keeps API discovery within it' do
      config = { 'url' => 'https://rubyllm.com', 'baseurl' => '/ruby_llm/next',
                 'vitepress_version' => { 'id' => 'next', 'kind' => 'next', 'title' => 'Next (unreleased)' },
                 'jekyll_vitepress' => {
                   'llms' => { 'details' => 'https://rubyllm.com/api/index.md https://rubyllm.com/models.json' }
                 } }

      VersionedDocs.prepare(double(config:))

      expect(config['docs_channel']).to eq('next')
      expect(config['docs_unreleased']).to be(true)
      expect(config.dig('jekyll_vitepress', 'llms')).to include(
        'description' => 'Developer documentation for RubyLLM Next (unreleased).',
        'details' => 'https://rubyllm.com/ruby_llm/next/api/index.md https://rubyllm.com/models.json'
      )
    end

    it 'keeps main out of search: no sitemap, and noindex on every page' do
      config = { 'url' => 'https://rubyllm.com', 'baseurl' => '/next',
                 'vitepress_version' => { 'id' => 'next', 'kind' => 'next', 'title' => 'Next (unreleased)' },
                 'jekyll_vitepress' => { 'seo' => { 'page_type' => 'TechArticle' } } }
      VersionedDocs.prepare(double(config:))
      page = rendered_page(<<~HTML, channel: 'next', theme: 'jekyll-vitepress-theme')
        <html><head><title>Chat | RubyLLM Next</title>
        <meta name="robots" content="index,follow,max-image-preview:large,max-snippet:-1,max-video-preview:-1">
        <link rel="canonical" href="https://rubyllm.com/next/chat/">
        </head><body><p>name="robots"</p></body></html>
      HTML
      page.site.config['docs_unreleased'] = config['docs_unreleased']
      redirect = rendered_page('<html><head><title>Redirecting</title></head><body></body></html>',
                               channel: 'next', theme: 'jekyll-vitepress-theme')
      redirect.site.config['docs_unreleased'] = true

      VersionedDocs.keep_out_of_search(page)
      VersionedDocs.keep_out_of_search(redirect)

      expect(config.dig('jekyll_vitepress', 'seo')).to eq('page_type' => 'TechArticle', 'sitemap' => false)
      head = Nokogiri::HTML(page.output)
      expect(head.css('meta[name="robots"]').map { |meta| meta['content'] }).to eq(['noindex,follow'])
      expect(head.at_css('link[rel=canonical]')['href']).to eq('https://rubyllm.com/next/chat/')
      expect(Nokogiri::HTML(redirect.output).at_css('head meta[name="robots"]')['content']).to eq('noindex,follow')
    end

    it 'leaves the stable docs indexed, with their sitemap' do
      config = { 'url' => 'https://rubyllm.com',
                 'vitepress_version' => { 'id' => 'stable', 'kind' => 'stable', 'title' => '2.2' },
                 'jekyll_vitepress' => { 'seo' => { 'page_type' => 'TechArticle' } } }
      VersionedDocs.prepare(double(config:))
      output = '<html><head><meta name="robots" content="index,follow"></head><body></body></html>'
      page = rendered_page(output.dup, channel: 'stable', theme: 'jekyll-vitepress-theme')
      page.site.config['docs_unreleased'] = config['docs_unreleased']

      VersionedDocs.keep_out_of_search(page)

      expect(config.dig('jekyll_vitepress', 'seo')).to eq('page_type' => 'TechArticle')
      expect(page.output).to eq(output)
    end

    it 'leaves a plain build without a version alone' do
      llms = { 'description' => 'Developer documentation.', 'details' => '' }
      config = { 'url' => 'https://rubyllm.com', 'jekyll_vitepress' => { 'llms' => llms } }

      VersionedDocs.prepare(double(config:))

      expect(config['docs_channel']).to be_nil
      expect(config['docs_unreleased']).to be(false)
      expect(llms['description']).to eq('Developer documentation.')
    end

    it 'names the docs version in the titles of the 1.x docs and their link previews' do
      page = rendered_page(<<~HTML, channel: 'v1')
        <html><head><title>Chat | RubyLLM</title>
        <meta property="og:title" content="Chat"><meta name="twitter:title" content="Chat">
        </head><body><svg><title>Copy</title></svg></body></html>
      HTML

      VersionedDocs.label_titles(page)
      head = Nokogiri::HTML(page.output)

      expect(head.at_css('head title').text).to eq('Chat | RubyLLM v1')
      expect(head.at_css('meta[property="og:title"]')['content']).to eq('Chat | RubyLLM v1')
      expect(head.at_css('meta[name="twitter:title"]')['content']).to eq('Chat | RubyLLM v1')
      expect(head.at_css('svg title').text).to eq('Copy')
    end

    it 'leaves titles to the theme in the docs it renders' do
      page = rendered_page('<html><head><title>Chat | RubyLLM Next</title></head></html>',
                           channel: 'next', theme: 'jekyll-vitepress-theme')

      expect { VersionedDocs.label_titles(page) }.not_to(change(page, :output))
    end

    it 'puts the version after the site name when a title starts with it' do
      expect(VersionedDocs.labeled_title('RubyLLM', 'RubyLLM', 'RubyLLM v1')).to eq('RubyLLM v1')
      expect(VersionedDocs.labeled_title('RubyLLM: the Ruby AI framework', 'RubyLLM', 'RubyLLM Next'))
        .to eq('RubyLLM Next: the Ruby AI framework')
      expect(VersionedDocs.labeled_title('RubyLLM | One framework', 'RubyLLM', 'RubyLLM v1'))
        .to eq('RubyLLM v1 | One framework')
      expect(VersionedDocs.labeled_title('RubyLLMs explained', 'RubyLLM', 'RubyLLM v1'))
        .to eq('RubyLLMs explained | RubyLLM v1')
    end

    it 'does not repeat the site name after a title that already starts with it' do
      home = double(data: { '_seo' => { 'page_title' => 'RubyLLM: the Ruby AI framework',
                                        'title' => 'RubyLLM: the Ruby AI framework | RubyLLM' } })
      chat = double(data: { '_seo' => { 'page_title' => 'Chat', 'title' => 'Chat | RubyLLM' } })
      site = double(config: { 'title' => 'RubyLLM' }, pages: [home, chat], collections: {})

      VersionedDocs.keep_branded_titles(site)

      expect(home.data.dig('_seo', 'title')).to eq('RubyLLM: the Ruby AI framework')
      expect(chat.data.dig('_seo', 'title')).to eq('Chat | RubyLLM')
    end
  end

  describe 'preparing each version' do
    def prepare(id, source)
      env = { 'VITEPRESS_DOCS' => File.join(root, 'docs'), 'VITEPRESS_VERSION_SOURCE' => source,
              'VITEPRESS_VERSION_ROOT' => root, 'VITEPRESS_VERSION_ID' => id }
      output, status = Open3.capture2e(env, RbConfig.ruby, File.join(root, 'docs/bin/prepare_version.rb'))
      expect(status.success?).to be(true), output
    end

    it 'gives the 1.x docs their version selector and banner, without the retired social image plugin' do
      write_page('_config.yml', "plugins:\n  - jekyll-og-image\n  - jekyll-seo-tag\n")
      write_page('_sass/custom/custom.scss', '')
      write_page('_includes/head.html', '')
      write_page('_includes/head_custom.html', '')
      write_page('_layouts/default.html', "<body>\n    {% include components/header.html %}\n</body>\n")
      write_page('_advanced/rails.md', File.read(File.join(root, 'spec/fixtures/docs/one_x_rails.md')))

      prepare('v1', site)

      expect(File.read(File.join(site, '_layouts/default.html')))
        .to include("{% include version_banner.html %}\n    {% include version_select.html %}")
      expect(File).to exist(File.join(site, '_includes/version_select.html'))
      expect(YAML.load_file(File.join(site, '_config.yml'))['plugins']).not_to include('jekyll-og-image')
      expect(File).not_to exist(File.join(site, '_reference/available-models.md'))
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
        .to eq('https://rubyllm.com/ruby_llm/next/assets/images/social/index.png')
      expect(html(path).css('a').map { |link| link['href'] }).to eq([
                                                                      'https://rubyllm.com/ruby_llm/next/',
                                                                      'https://rubyllm.com/ruby_llm/next/upgrading/',
                                                                      'https://github.com/crmne/ruby_llm'
                                                                    ])
    end

    it 'names the docs version in API page titles outside the stable docs' do
      write_page('next/api/RubyLLM/Chat.html', <<~HTML)
        <html><head><title>class RubyLLM::Chat - RubyLLM</title>
        <meta property="og:title" content="class RubyLLM::Chat - RubyLLM"></head><body></body></html>
      HTML
      write_page('api/RubyLLM/Chat.html', '<html><head><title>class RubyLLM::Chat - RubyLLM</title></head></html>')
      run_script('postprocess_api_seo.rb', File.join(site, 'next/api'), 'https://rubyllm.com/next')
      run_script('postprocess_api_seo.rb', File.join(site, 'api'), 'https://rubyllm.com')

      expect(html('next/api/RubyLLM/Chat.html').at_css('title').text).to eq('class RubyLLM::Chat - RubyLLM Next')
      expect(html('next/api/RubyLLM/Chat.html').at_css('meta[property="og:title"]')['content'])
        .to eq('class RubyLLM::Chat - RubyLLM Next')
      expect(html('api/RubyLLM/Chat.html').at_css('title').text).to eq('class RubyLLM::Chat - RubyLLM')
    end
  end

  describe 'API pages in search' do
    def api_page(relative)
      write_page(relative, '<html><head><title>class RubyLLM::Chat - RubyLLM</title></head><body></body></html>')
    end

    def robots(relative)
      html(relative).at_css('meta[name="robots"]')['content']
    end

    it 'keeps main\'s API pages out of search and indexes the stable ones' do
      api_page('next/api/RubyLLM/Chat.html')
      api_page('api/RubyLLM/Chat.html')
      write_page('sitemap.xml', "<urlset>\n</urlset>\n")
      run_script('postprocess_api_seo.rb', File.join(site, 'next/api'), 'https://rubyllm.com/next')
      run_script('postprocess_api_seo.rb', File.join(site, 'api'), 'https://rubyllm.com')

      expect(robots('next/api/RubyLLM/Chat.html')).to eq('noindex,follow')
      expect(robots('api/RubyLLM/Chat.html')).to start_with('index,follow')
      expect(File.read(File.join(site, 'sitemap.xml'))).to include('https://rubyllm.com/api/RubyLLM/Chat.html')
    end

    it 'keeps RDoc\'s pages for generator templates out of search and the sitemap' do
      template = 'v1/api/lib/generators/ruby_llm/agent/templates/agent_rb_tt.html'
      api_page(template)
      api_page('v1/api/RubyLLM/Chat.html')
      write_page('v1/sitemap.xml', "<urlset>\n</urlset>\n")
      run_script('postprocess_api_seo.rb', File.join(site, 'v1/api'), 'https://rubyllm.com/v1')

      sitemap = File.read(File.join(site, 'v1/sitemap.xml'))
      expect(robots(template)).to eq('noindex,follow')
      expect(robots('v1/api/RubyLLM/Chat.html')).to start_with('index,follow')
      expect(sitemap).to include('https://rubyllm.com/v1/api/RubyLLM/Chat.html')
      expect(sitemap).not_to include('templates')
    end
  end

  describe 'frozen 1.x assets' do
    before do
      write_page('_sass/custom/custom.scss', <<~SCSS)
        @media (prefers-color-scheme: dark) {
          .provider-logo img[src*="-text.svg"],
          .provider-logo img[src*="/openrouter.svg"],

          .site-logo {
            background-image: url('/assets/images/logotype_dark.svg');
          }
        }
      SCSS
    end

    it 'inverts dark provider logos instead of painting the site logo on them' do
      write_page('_config.yml', '{}')
      write_page('_includes/head.html', '')
      write_page('_includes/head_custom.html', '')
      write_page('_layouts/default.html', '')
      write_page('_advanced/rails.md', File.read(File.join(root, 'spec/fixtures/docs/one_x_rails.md')))

      run_script('prepare_one_x_docs.rb', site)

      expect(File.read(File.join(site, '_sass/custom/custom.scss')))
        .to match(/openrouter\.svg"\] \{\n\s+filter: invert\(1\);\n\s+\}\n\n\s+\.site-logo \{/)
    end

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
        'path' => '/assets/images/social/index.png',
        'alt' => 'RubyLLM',
        'width' => 1200,
        'height' => 630
      )
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
