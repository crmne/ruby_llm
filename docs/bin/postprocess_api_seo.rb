# frozen_string_literal: true

require 'cgi'
require 'json'
require 'pathname'

output_dir = Pathname(ARGV.fetch(0)).expand_path
site_root = ARGV.fetch(1).sub(%r{/+\z}, '')
image_url = "#{site_root}/assets/images/logotype.jpg"
default_robots = 'index,follow,max-image-preview:large,max-snippet:-1,max-video-preview:-1'
api_urls = []

def tag(name, attributes)
  rendered = attributes.map { |key, value| %(#{key}="#{CGI.escapeHTML(value)}") }.join(' ')
  "<#{name} #{rendered}>"
end

def inject_head(html, content)
  html.sub(/<head>/i, "<head>\n#{content}")
end

# Escapes the characters that would let a value close the ld+json block early.
def json_ld(graph)
  JSON.generate(graph).gsub(/[<>&\u2028\u2029]/) { |char| format('\\u%04x', char.ord) }
end

# rubocop:disable Metrics/BlockLength
output_dir.glob('**/*.html').sort.each do |path|
  relative_path = path.relative_path_from(output_dir).to_s
  html = path.read
  redirect = html.match?(/<meta[^>]+http-equiv="refresh"/i)
  target = html[/<meta[^>]+http-equiv="refresh"[^>]+url=([^";]+)[^>]*>/i, 1]
  canonical = if relative_path == 'index.html'
                "#{site_root}/api/"
              elsif redirect && target
                "#{site_root}/api/#{target}"
              else
                "#{site_root}/api/#{relative_path}"
              end
  robots = redirect ? 'noindex,follow' : default_robots
  title = CGI.unescapeHTML(html[%r{<title>(.*?)</title>}mi, 1].to_s).strip
  description = CGI.unescapeHTML(html[/<meta\s+name="description"\s+content="([^"]*)"/mi, 1].to_s).strip

  html.sub!(/<link\s+rel="canonical"\s+href="[^"]*">/i, '')
  metadata = [
    tag('link', 'rel' => 'canonical', 'href' => canonical),
    tag('meta', 'name' => 'robots', 'content' => robots),
    tag('meta', 'property' => 'og:url', 'content' => canonical),
    tag('meta', 'property' => 'og:image', 'content' => image_url),
    tag('meta', 'property' => 'og:image:alt', 'content' => 'RubyLLM'),
    tag('meta', 'name' => 'twitter:image', 'content' => image_url)
  ]

  unless redirect
    website_id = "#{site_root}/#website"
    webpage_id = "#{canonical}#webpage"
    graph = {
      '@context' => 'https://schema.org',
      '@graph' => [
        {
          '@type' => 'WebSite', '@id' => website_id, 'url' => "#{site_root}/",
          'name' => 'RubyLLM',
          'description' => 'The Ruby-native AI framework for building with every major provider.',
          'inLanguage' => 'en-US'
        },
        {
          '@type' => 'ImageObject', '@id' => "#{image_url}#primaryimage",
          'url' => image_url, 'contentUrl' => image_url,
          'caption' => 'RubyLLM', 'width' => 579, 'height' => 200
        },
        {
          '@type' => 'WebPage', '@id' => webpage_id, 'url' => canonical,
          'name' => title, 'description' => description,
          'isPartOf' => { '@id' => website_id }, 'inLanguage' => 'en-US',
          'primaryImageOfPage' => { '@id' => "#{image_url}#primaryimage" }
        }
      ]
    }
    metadata << %(<script type="application/ld+json">#{json_ld(graph)}</script>)
    api_urls << canonical
  end

  html = inject_head(html, metadata.join("\n"))
  html.sub!(/<body\b/i, "</head>\n<body") unless html.match?(%r{</head>}i)
  html = "#{html.rstrip}\n</html>\n" unless html.match?(%r{</html>}i)
  path.write(html)
end
# rubocop:enable Metrics/BlockLength

sitemap_path = output_dir.parent.join('sitemap.xml')
if sitemap_path.file?
  sitemap = sitemap_path.read
  rows = api_urls.uniq.sort.map do |url|
    "  <url>\n    <loc>#{CGI.escapeHTML(url)}</loc>\n  </url>"
  end.join("\n")
  sitemap.sub!(%r{</urlset>}, "#{rows}\n</urlset>")
  sitemap_path.write(sitemap)
end
