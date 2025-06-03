# frozen_string_literal: true

class Chat < ApplicationRecord
  include RubyLLM::ActiveRecord::ActsAs
  acts_as_chat
end
