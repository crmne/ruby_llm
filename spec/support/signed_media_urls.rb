# frozen_string_literal: true

module SignedMediaUrls
  AZURE_BLOB_URL = %r{https?://[a-z0-9.-]+\.blob\.core\.windows\.net/[^\s"'<>\\]+}i

  def self.sanitize(value)
    value.gsub(AZURE_BLOB_URL) { |url| url.gsub(/([?&]sig=)[^&]*/i, '\1FILTERED_SIGNATURE') }
  end

  def self.filter(interaction)
    interaction.request.uri = sanitize(interaction.request.uri)
    [interaction.request, interaction.response].each do |message|
      message.body = sanitize(message.body) if message.body&.valid_encoding?
      message.headers.each do |key, values|
        message.headers[key] = values.map { |value| sanitize(value) } if key.casecmp?('location')
      end
    end
  end
end
