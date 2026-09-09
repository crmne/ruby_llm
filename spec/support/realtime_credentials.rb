# frozen_string_literal: true

module RealtimeCredentials
  CREDENTIAL = /\A(?:token|access_token|authorization|api_key|xi[_-]api[_-]key|
                    persistent_session_token|session_token|single_use_token|conversation_signature|
                    newHandle|new_handle|headers)\z/ix

  def self.sanitize(value, redact_audio: false)
    case value
    when Hash
      value.to_h do |key, item|
        [key, sanitize_item(value, key.to_s, item, redact_audio:)]
      end
    when Array then value.map { |item| sanitize(item, redact_audio:) }
    else value
    end
  end

  def self.sanitize_item(value, key, item, redact_audio:)
    if redact_audio && value['type'] == 'input_audio_buffer.append' && key == 'audio'
      { 'sha256' => Digest::SHA256.hexdigest(Base64.strict_decode64(item)) }
    elsif redact_audio && key == 'realtimeInput' && item.dig('audio', 'data')
      audio = item.fetch('audio').merge('data' => { 'sha256' => Digest::SHA256.hexdigest(
        Base64.strict_decode64(item.dig('audio', 'data'))
      ) })
      sanitize(item.merge('audio' => audio), redact_audio: false)
    else
      sanitize_field(key, item, redact_audio:)
    end
  end

  def self.sanitize_field(key, value, redact_audio:)
    case key
    when CREDENTIAL then '[FILTERED]'
    when 'signed_url' then sanitize_url(value)
    when 'model'
      value.is_a?(String) ? value.sub(%r{\Aprojects/[^/]+/}, 'projects/[FILTERED]/') : value
    when 'audio_base_64', 'user_audio_chunk'
      redact_audio ? { 'sha256' => Digest::SHA256.hexdigest(Base64.strict_decode64(value)) } : value
    else sanitize(value, redact_audio:)
    end
  end

  def self.sanitize_url(value)
    uri = URI.parse(value)
    if uri.query
      params = URI.decode_www_form(uri.query).to_h
      params['key'] = '[FILTERED]' if params.key?('key')
      uri.query = URI.encode_www_form(sanitize(params))
    end
    uri.to_s
  rescue URI::InvalidURIError
    '[FILTERED]'
  end

  def self.filter_elevenlabs(interaction)
    return unless interaction.request.uri.match?(%r{\Ahttps?://api\.elevenlabs\.io(?::\d+)?(?:[/?#]|\z)}i)

    interaction.request.uri = sanitize_url(interaction.request.uri)
    [interaction.request, interaction.response].each do |message|
      next unless message.body&.start_with?('{', '[')

      original = JSON.parse(message.body)
      filtered = sanitize(original)
      message.body = JSON.generate(filtered) unless filtered == original
    rescue JSON::ParserError
      next
    end
  end
end
