# frozen_string_literal: true

module RubyLLM
  # An OCR is the text a document AI model extracted from a file.
  # RubyLLM.ocr returns one. Each page carries the extracted markdown along
  # with any images and tables the provider reports.
  #
  #   ocr = RubyLLM.ocr("contract.pdf")
  #   ocr.markdown             # => "# Contract\n\n..."
  #   ocr.pages.first.markdown # => "# Contract\n..."
  #
  class OCR
    include Inspectable
    include Usage::Result

    # One page of an OCR result: the zero-based page +index+, the extracted
    # +markdown+, and the +images+ and +tables+ the provider reports for the
    # page, or +nil+ when it reports none. +raw+ holds the provider's
    # unmodified page hash, including any fields beyond these.
    Page = Struct.new(:index, :markdown, :images, :tables, :raw, keyword_init: true)

    # The id of the model that performed the OCR.
    attr_reader :model

    # The provider's usage block for the request, such as the number of
    # pages processed, or +nil+ when the provider does not report one.
    attr_reader :usage # :nodoc:

    # The provider's raw response hash.
    attr_reader :raw

    # Extracts the text of +file+ and returns an OCR result. Most code calls
    # this through RubyLLM.ocr. The file may be a path, URL, IO object, or
    # Attachment; PDFs, office documents, and images are accepted.
    #
    # +model:+ selects the OCR model and defaults to the configured
    # +default_ocr_model+. +provider:+ forces a specific provider, and
    # +assume_model_exists:+ skips the registry lookup. +context:+ supplies
    # a Context whose configuration replaces the global one. +metadata:+ is
    # included in the instrumentation payload. Every other keyword passes
    # through to the request in the provider's own vocabulary, such as
    # Mistral's +pages:+, +include_image_base64:+, or +table_format:+.
    #
    #   RubyLLM.ocr("report.pdf")
    #   RubyLLM.ocr("https://example.com/scan.png")
    #   RubyLLM.ocr("report.pdf", pages: [0, 1], table_format: "html")
    #
    # Raises RubyLLM::ModelNotFoundError if +model:+ is not in the registry,
    # and RubyLLM::Error when the provider has no OCR support.
    def self.ocr(file,
                 model: nil,
                 provider: nil,
                 assume_model_exists: false,
                 context: nil,
                 provider_options: {},
                 metadata: nil)
      config = context&.config || RubyLLM.config
      model ||= config.default_ocr_model
      model, provider_instance = Models.resolve(model, provider: provider, assume_model_exists: assume_model_exists,
                                                       config: config)
      payload = {
        provider: provider_instance.slug,
        provider_class: provider_instance.class.display_name,
        model: model.id,
        model_info: model,
        provider_options: provider_options,
        metadata: metadata
      }

      RubyLLM.instrument('ocr.ruby_llm', payload, config: config) do |event|
        result = provider_instance.ocr(file, model:, provider_options:)
        event[:result] = result
        event[:response_model] = result.model
        result
      end
    end

    def initialize(pages:, model:, usage: nil, raw: nil) # :nodoc:
      @page_hashes = Array(pages)
      @model = model
      @usage = usage
      @raw = raw
    end

    # Returns the pages of the document as an array of Page structs.
    def pages
      @pages ||= @page_hashes.map.with_index do |page, position|
        Page.new(
          index: page['index'] || position,
          markdown: page['markdown'],
          images: page['images'],
          tables: page['tables'],
          raw: page
        )
      end
    end

    # Returns the markdown of every page, joined with blank lines.
    def markdown
      pages.filter_map(&:markdown).join("\n\n")
    end

    def inspect_attributes # :nodoc:
      { model: model, pages: pages.length }
    end
  end
end
