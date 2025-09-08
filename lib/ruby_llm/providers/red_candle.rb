# frozen_string_literal: true

module RubyLLM
  module Providers
    # Red Candle provider for local LLM execution using the Candle Rust crate.
    class RedCandle < Provider
      include RedCandle::Chat
      include RedCandle::Models
      include RedCandle::Capabilities
      include RedCandle::Streaming

      def initialize(config)
        ensure_red_candle_available!
        super
        @loaded_models = {} # Cache for loaded models
        @device = determine_device(config)
      end

      def api_base
        nil # Local execution, no API base needed
      end

      def headers
        {} # No HTTP headers needed
      end

      class << self
        def capabilities
          RedCandle::Capabilities
        end

        def configuration_requirements
          [] # No required config, device is optional
        end

        def local?
          true
        end

        def supports_functions?(model_id = nil)
          RedCandle::Capabilities.supports_functions?(model_id)
        end
      end

      private

      def ensure_red_candle_available!
        require 'candle'
      rescue LoadError
        raise Error.new(nil, "Red Candle gem is not installed. Add 'gem \"red-candle\", \"~> 1.2.3\"' to your Gemfile.")
      end

      def determine_device(config)
        if config.red_candle_device
          case config.red_candle_device.to_s.downcase
          when 'cpu'
            ::Candle::Device.cpu
          when 'cuda', 'gpu'
            ::Candle::Device.cuda
          when 'metal'
            ::Candle::Device.metal
          else
            ::Candle::Device.best
          end
        else
          ::Candle::Device.best
        end
      rescue StandardError => e
        RubyLLM.logger.warn "Failed to initialize device: #{e.message}. Falling back to CPU."
        ::Candle::Device.cpu
      end
    end
  end
end