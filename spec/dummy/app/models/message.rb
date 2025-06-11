# frozen_string_literal: true

class Message < ApplicationRecord
  include RubyLLM::ActiveRecord::ActsAs
  acts_as_message
  has_many_attached :attachments
end
