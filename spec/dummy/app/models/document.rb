# frozen_string_literal: true

class Document < ApplicationRecord
  has_one_attached :file
  has_many_attached :files
end
