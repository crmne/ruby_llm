# frozen_string_literal: true

class Message < ApplicationRecord
  acts_as_message
  has_many_attached :attachments
end
