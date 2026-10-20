# frozen_string_literal: true

# A key 1Password could not read reaches the specs as an empty string. The
# specs read a missing key as "replay the cassette with a placeholder", so an
# empty one must count as missing too. Otherwise the provider refuses the empty
# key as unconfigured, the example fails, and the failure deletes its cassette:
# a partial .env would wipe every recording of that provider.
module BlankKeys
  CREDENTIAL = /_(API_KEY|API_BASE|AUTH_KEY|ACCESS_KEY_ID|SECRET_ACCESS_KEY|SESSION_TOKEN)\z/

  module_function

  def clear(env = ENV, dotenv: File.expand_path('../../.env', __dir__))
    names = env.keys.grep(CREDENTIAL) | names_in(dotenv)
    names.each { |name| env.delete(name) if env.key?(name) && env[name].strip.empty? }
  end

  def names_in(path)
    return [] unless File.exist?(path)

    File.foreach(path).filter_map { |line| line[/\A\s*(?:export\s+)?([A-Za-z_]\w*)\s*=/, 1] }
  end
end

BlankKeys.clear
