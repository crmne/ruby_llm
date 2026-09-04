# frozen_string_literal: true

module QueryHelpers
  def self.matching(pattern)
    queries = []
    thread = Thread.current
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |_name, _start, _finish, _id, payload|
      next unless Thread.current == thread
      next if payload[:name] == 'SCHEMA' || payload[:cached]

      queries << payload[:sql] if payload[:sql].match?(pattern)
    end

    yield

    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
