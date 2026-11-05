# frozen_string_literal: true

# Renders Liquid in the site description and in front-matter descriptions, so
# facts such as {{ site.provider_count }} live once in _config.yml and reach
# meta tags, JSON-LD, and llms.txt the same way they reach page content.
module LiquidMetadata
  module_function

  def apply(site)
    payload = { 'site' => site.config }
    site.config['description'] = render(site.config['description'], payload)
    (site.pages + site.collections.values.flat_map(&:docs)).each do |page|
      page.data['description'] = render(page.data['description'], payload) if page.data.key?('description')
    end
  end

  def render(value, payload)
    return value unless value.is_a?(String) && value.include?('{{')

    Liquid::Template.parse(value).render!(payload)
  end
end

Jekyll::Hooks.register :site, :post_read, priority: :high do |site|
  LiquidMetadata.apply(site)
end
