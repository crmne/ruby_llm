# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Storage adapter for handling attachments
    class AttachmentStorage
      class << self
        def for(type)
          case type
          when :base64
            Base64Adapter.new
          else
            raise ArgumentError, "Unknown attachment storage type: #{type}" unless type.respond_to?(:call)

            CustomAdapter.new(type)
          end
        end
      end

      # Base adapter interface
      class BaseAdapter
        def store_attachment(part, record: nil)
          raise NotImplementedError, "#{self.class} must implement #store_attachment"
        end

        def retrieve_attachment(part, record: nil)
          raise NotImplementedError, "#{self.class} must implement #retrieve_attachment"
        end
      end

      # Base64 adapter (stores attachments as base64 in the database)
      class Base64Adapter < BaseAdapter
        def store_attachment(part, record: nil) # rubocop:disable Lint/UnusedMethodArgument
          # Already in base64 format, just return as is
          part
        end

        def retrieve_attachment(part, record: nil) # rubocop:disable Lint/UnusedMethodArgument
          # Already in base64 format, just return as is
          part
        end
      end

      # Custom adapter (uses a custom callable)
      class CustomAdapter < BaseAdapter
        def initialize(callable)
          super()
          @callable = callable
        end

        def store_attachment(part, record: nil)
          @callable.call(:store, part, record: record)
        end

        def retrieve_attachment(part, record: nil)
          @callable.call(:retrieve, part, record: record)
        end
      end
    end
  end
end
