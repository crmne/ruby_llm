# frozen_string_literal: true

# jekyll-sass-converter 3.x doesn't forward deprecation options from `sass:` config.
# This patch passes them through to Dart Sass so docs builds can silence upstream
# deprecations from remote themes.
module DocsSassDeprecationOptions
  def sass_configs
    configs = super

    add_sass_array_option(configs, :silence_deprecations)
    add_sass_array_option(configs, :future_deprecations)
    add_sass_array_option(configs, :fatal_deprecations)

    configs
  end

  private

  def add_sass_array_option(configs, key)
    values = Array(jekyll_sass_configuration[key.to_s]).compact.map(&:to_s)
    return if values.empty?

    configs[key] = values.map(&:to_sym)
  end
end

Jekyll::Converters::Scss.prepend(DocsSassDeprecationOptions) \
  unless Jekyll::Converters::Scss < DocsSassDeprecationOptions
