# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Providers::Gemini::Capabilities do
  describe ".context_window_for" do
    it "returns the correct context window for Gemini 2.5 models" do
      expect(described_class.context_window_for("gemini-2.5-flash-preview-05-20")).to eq(1_048_576)
      expect(described_class.context_window_for("gemini-2.5-pro-preview-05-06")).to eq(2_097_152)
    end
  end

  describe ".max_tokens_for" do
    it "returns the correct max tokens for Gemini 2.5 models" do
      expect(described_class.max_tokens_for("gemini-2.5-flash-preview-05-20")).to eq(8_192)
      expect(described_class.max_tokens_for("gemini-2.5-pro-preview-05-06")).to eq(64_000)
    end
  end

  describe ".model_family" do
    it "identifies the correct model family for Gemini 2.5 models" do
      expect(described_class.model_family("gemini-2.5-flash-preview-05-20")).to eq("gemini25_flash_preview")
      expect(described_class.model_family("gemini-2.5-pro-preview-05-06")).to eq("gemini25_pro_preview")
      expect(described_class.model_family("gemini-2.5-flash-preview-tts")).to eq("gemini25_flash_preview_tts")
      expect(described_class.model_family("gemini-2.5-pro-preview-tts")).to eq("gemini25_pro_preview_tts")
      expect(described_class.model_family("gemini-2.5-flash-preview-native-audio-dialog")).to eq("gemini25_flash_preview_audio")
    end
  end

  describe ".pricing_family" do
    it "assigns the correct pricing family for Gemini 2.5 models" do
      expect(described_class.pricing_family("gemini-2.5-flash-preview-05-20")).to eq(:flash_2_5)
      expect(described_class.pricing_family("gemini-2.5-pro-preview-05-06")).to eq(:pro_2_5)
    end
  end

  describe ".long_context_model?" do
    it "correctly identifies Gemini 2.5 models as long context" do
      expect(described_class.long_context_model?("gemini-2.5-flash-preview-05-20")).to be true
      expect(described_class.long_context_model?("gemini-2.5-pro-preview-05-06")).to be true
    end
  end

  describe ".modalities_for" do
    it "includes audio output for TTS models" do
      expect(described_class.modalities_for("gemini-2.5-flash-preview-tts")[:output]).to include("audio")
      expect(described_class.modalities_for("gemini-2.5-pro-preview-tts")[:output]).to include("audio")
    end

    it "includes audio input for Gemini 2.5 models" do
      expect(described_class.modalities_for("gemini-2.5-flash-preview-05-20")[:input]).to include("audio")
      expect(described_class.modalities_for("gemini-2.5-pro-preview-05-06")[:input]).to include("audio")
    end
  end

  describe ".supports_vision?" do
    it "returns true for Gemini 2.5 models" do
      expect(described_class.supports_vision?("gemini-2.5-flash-preview-05-20")).to be true
      expect(described_class.supports_vision?("gemini-2.5-pro-preview-05-06")).to be true
    end
  end

  describe ".supports_functions?" do
    it "returns true for Gemini 2.5 models" do
      expect(described_class.supports_functions?("gemini-2.5-flash-preview-05-20")).to be true
      expect(described_class.supports_functions?("gemini-2.5-pro-preview-05-06")).to be true
    end
  end

  describe ".supports_json_mode?" do
    it "returns true for Gemini 2.5 models" do
      expect(described_class.supports_json_mode?("gemini-2.5-flash-preview-05-20")).to be true
      expect(described_class.supports_json_mode?("gemini-2.5-pro-preview-05-06")).to be true
    end
  end

  describe ".capabilities_for" do
    it "includes appropriate capabilities for Gemini 2.5 models" do
      capabilities = described_class.capabilities_for("gemini-2.5-flash-preview-05-20")
      expect(capabilities).to include("streaming")
      expect(capabilities).to include("function_calling")
      expect(capabilities).to include("structured_output")
      expect(capabilities).to include("batch")
    end
  end
end