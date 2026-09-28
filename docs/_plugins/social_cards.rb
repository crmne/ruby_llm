# frozen_string_literal: true

require 'cgi'
require 'digest'
require 'fileutils'
require 'uri'
require 'vips'

module SocialCards
  WIDTH = 1200
  HEIGHT = 630
  MARGIN = 80
  BAR = 10
  FONTS = File.join(__dir__, 'social_cards', 'fonts')
  DESIGN = Digest::SHA256.file(__FILE__).hexdigest
  OUTPUT_DIR = 'assets/images/social'

  COLORS = {
    background: 'F7F3F1',
    grid: 'E6DDD7',
    title: 'B30000',
    heading: '2C2926',
    text: '5C5353',
    muted: '796B67',
    label: '9D0006',
    highlight: 'F2DCD8'
  }.freeze

  TYPE = {
    title: ['Lora SemiBold', 'Lora-SemiBold.ttf'],
    headline: ['Lora Bold', 'Lora-Bold.ttf'],
    text: ['Inter', 'Inter-Regular.ttf'],
    label: ['Inter SemiBold', 'Inter-SemiBold.ttf'],
    code: ['IBM Plex Mono', 'IBMPlexMono-Regular.ttf']
  }.freeze

  class Generator < Jekyll::Generator
    priority :lowest

    def generate(site)
      cache = site.in_source_dir(site.config.fetch('cache_dir', '.jekyll-cache'), 'social-cards')
      FileUtils.mkdir_p(cache)
      logo = site.in_source_dir('assets/images/logotype.svg')
      logo = nil unless File.exist?(logo)

      pages(site).each do |page|
        card = Card.new(site, page, logo)
        source = File.join(cache, "#{card.digest}.png")
        card.render(source) unless File.exist?(source)
        site.static_files << CardFile.new(site, card.filename, source)
        page.data['image'] = {
          'path' => "/#{OUTPUT_DIR}/#{card.filename}", 'width' => WIDTH, 'height' => HEIGHT, 'alt' => card.title
        }
      end
    end

    private

    def pages(site)
      (site.pages + site.collections.values.flat_map(&:docs)).select do |page|
        page.output_ext == '.html' && page.data['title'] && !page.data['redirect'] &&
          !page.data.key?('image') && page.write?
      end
    end
  end

  class CardFile < Jekyll::StaticFile
    def initialize(site, name, source)
      super(site, site.source, OUTPUT_DIR, name)
      @card_source = source
    end

    def path
      @card_source
    end
  end

  class Card
    attr_reader :title

    def initialize(site, page, logo)
      @site = site
      @page = page
      @logo = logo
      tagline = clean(site.config['tagline'])
      @home = page.url == '/' && tagline.split.size > 3
      @title = @home ? tagline : clean(page.data['title'])
      @description = clean(page.data['description'] || site.config['description'])
    end

    def filename
      slug = @page.url.delete_prefix('/').delete_suffix('/').tr('/', '-')
      "#{slug.empty? ? 'index' : slug}.png"
    end

    def digest
      Digest::SHA256.hexdigest([DESIGN, @title, @description, section, address, logo_digest].join("\0"))
    end

    def render(path)
      canvas = background.composite2(decoration, :over)
      canvas = canvas.composite2(Vips::Image.svgload(@logo, scale: 60.0 / 140), :over, x: MARGIN - 7, y: 60) if @logo
      canvas = draw_label(canvas) if section
      canvas = draw_body(canvas)
      canvas.write_to_file(path)
    end

    private

    def section
      return unless @page.is_a?(Jekyll::Document)

      @page.collection.label.split('_').map(&:capitalize).join(' ')
    end

    def address
      base = @site.config['baseurl'].to_s.delete_suffix('/')
      host = URI(@site.config.fetch('url', 'https://rubyllm.com')).host
      "#{host}#{base}#{@page.url}".delete_suffix('/')
    end

    def logo_digest
      @logo ? Digest::SHA256.file(@logo).hexdigest : ''
    end

    def clean(value)
      value.to_s.gsub(/<[^>]+>/, '').gsub(/\s+/, ' ').strip
    end

    def background
      Vips::Image.black(WIDTH, HEIGHT).new_from_image(rgb(COLORS[:background])).copy(interpretation: :srgb)
    end

    def decoration
      lines = (0..WIDTH).step(120).map { |x| %(<rect x="#{x}" width="1" height="#{HEIGHT}"/>) } +
              (30..HEIGHT).step(120).map { |y| %(<rect y="#{y}" width="#{WIDTH}" height="1"/>) }
      Vips::Image.svgload_buffer(<<~SVG)
        <svg xmlns="http://www.w3.org/2000/svg" width="#{WIDTH}" height="#{HEIGHT}">
          <defs>
            <radialGradient id="fade" cx="0.5" cy="0.45" r="0.75">
              <stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#fff" stop-opacity="0.25"/>
            </radialGradient>
            <mask id="grid"><rect width="#{WIDTH}" height="#{HEIGHT}" fill="url(#fade)"/></mask>
            <linearGradient id="bar" x1="0" x2="1">
              <stop offset="0.28" stop-color="#e24a2f"/><stop offset="0.78" stop-color="#9f1406"/>
            </linearGradient>
          </defs>
          <g fill="##{COLORS[:grid]}" mask="url(#grid)">#{lines.join}</g>
          <rect y="#{HEIGHT - BAR}" width="#{WIDTH}" height="#{BAR}" fill="url(#bar)"/>
        </svg>
      SVG
    end

    def draw_label(canvas)
      text = %(<span letter_spacing="2400">#{escape(section.upcase)}</span>)
      label = text(text, :label, 20, color: COLORS[:label])
      canvas.composite2(label, :over, x: WIDTH - MARGIN - label.width, y: 82)
    end

    def draw_body(canvas)
      width = WIDTH - (MARGIN * 2)
      url = text(escape(address), :code, 24, color: COLORS[:muted], width: width)
      url_y = HEIGHT - BAR - 56 - url.height
      heading = @home ? headline(width) : fit_title(width)
      description = fit_description(width - 40) unless @description.empty?
      gap = 36
      block = heading.height + (description ? gap + description.height : 0)
      top = 170
      y = top + [(url_y - 40 - top - block) / 2, 0].max

      layers = [[heading, y], [url, url_y]]
      layers << [description, y + heading.height + gap] if description
      canvas.composite(layers.map(&:first), :over, x: [MARGIN] * layers.size, y: layers.map(&:last))
    end

    def headline(width)
      words = @title.split
      emphasis = words.last(3).join(' ')
      lead = words[0...-3].join(' ')
      markup = %(#{escape(lead)}\n<span foreground="##{COLORS[:title]}" background="##{COLORS[:highlight]}"> ) +
               %(#{escape(emphasis)} </span>)
      text(markup, :headline, 72, color: COLORS[:heading], width: width)
    end

    def fit_title(width)
      [84, 76, 68, 60, 54].each do |size|
        title = text(escape(@title), :title, size, color: COLORS[:title], width: width)
        return title if lines(title, :title, size) <= 2
      end
      text(escape(@title), :title, 54, color: COLORS[:title], width: width)
    end

    def fit_description(width)
      words = @description.split
      loop do
        shown = words.join(' ')
        shown += '…' unless shown == @description
        description = text(escape(shown), :text, 32, color: COLORS[:text], width: width, spacing: 10)
        return description if lines(description, :text, 32, spacing: 10) <= 2 || words.size <= 1

        words.pop
      end
    end

    def lines(image, face, size, spacing: 0)
      one = text('Ay', face, size, color: COLORS[:text]).height
      ((image.height + spacing) / (one + spacing).to_f).round
    end

    def text(markup, face, size, color:, width: nil, spacing: 0)
      family, file = TYPE.fetch(face)
      options = { font: "#{family} #{size}", fontfile: File.join(FONTS, file), dpi: 72, rgba: true, spacing: spacing }
      options.merge!(width: width, wrap: :word) if width
      Vips::Image.text(%(<span foreground="##{color}">#{markup}</span>), **options)
    end

    def escape(value)
      CGI.escapeHTML(value)
    end

    def rgb(hex)
      hex.scan(/../).map { |pair| pair.to_i(16) }
    end
  end
end
