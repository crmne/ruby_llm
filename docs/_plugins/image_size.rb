# frozen_string_literal: true

# Provides `image_size`, which returns the width and height attributes of a
# local SVG or PNG, so browsers reserve each logo's space before it loads.
module ImageSize
  module_function

  NUMBER = /\A\s*(\d+(?:\.\d+)?)(?:px)?\s*\z/

  def dimensions(path)
    return unless File.file?(path)

    case File.extname(path).downcase
    when '.svg' then svg_dimensions(File.read(path, 4096))
    when '.png' then png_dimensions(File.binread(path, 24))
    end
  end

  def svg_dimensions(source)
    tag = source[/<svg\b[^>]*>/m].to_s
    width = tag[/\swidth="([^"]+)"/, 1].to_s[NUMBER, 1]
    height = tag[/\sheight="([^"]+)"/, 1].to_s[NUMBER, 1]
    return [width.to_f.round, height.to_f.round] if width && height

    view_box = tag[/\sviewBox="([^"]+)"/, 1]&.split(/[\s,]+/)&.map(&:to_f)
    [view_box[2].round, view_box[3].round] if view_box&.size == 4
  end

  def png_dimensions(header)
    return unless header&.bytesize == 24 && header.start_with?("\x89PNG".b)

    header.byteslice(16, 8).unpack('NN')
  end

  # Liquid filter: {{ '/assets/images/logo.svg' | image_size }}
  module Filter
    def image_size(path)
      return '' if path.to_s.include?('://') || path.to_s.start_with?('data:')

      site = @context.registers[:site]
      size = ImageSize.dimensions(File.join(site.source, path.to_s.delete_prefix('/')))
      size&.all?(&:positive?) ? %(width="#{size[0]}" height="#{size[1]}") : ''
    end
  end
end

Liquid::Template.register_filter(ImageSize::Filter)
