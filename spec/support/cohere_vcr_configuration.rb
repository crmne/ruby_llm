# frozen_string_literal: true

VCR.configure do |config|
  config.before_record do |interaction|
    uri = interaction.request.uri
    next unless uri.start_with?('https://api.cohere.com/',
                                'https://storage.googleapis.com/cohere-production-user-datasets/')

    credential = /X-Goog-(Signature|Credential)=[^&\s"\\]+/
    filter = lambda do |value|
      value.gsub(credential) { "X-Goog-#{Regexp.last_match(1)}=FILTERED_#{Regexp.last_match(1).upcase}" }
    end
    interaction.request.uri = filter.call(uri)
    next unless interaction.response.body&.valid_encoding?

    interaction.response.body = filter.call(interaction.response.body)
  end
end
