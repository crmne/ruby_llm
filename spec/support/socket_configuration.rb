# frozen_string_literal: true

RSpec.configure do |config|
  config.before do |example|
    next if example.metadata[:live]

    allow(Socket).to receive(:tcp).and_wrap_original do |original, host, *args, **options|
      unless %w[127.0.0.1 ::1 localhost].include?(host)
        raise "External socket connections require a :live spec (#{host})"
      end

      original.call(host, *args, **options)
    end
  end
end
