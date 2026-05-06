# frozen_string_literal: true

# Jekyll assigns custom collection documents a synthetic date based on build
# time. These docs are evergreen reference pages, so hide that synthetic date
# from Liquid consumers such as jekyll-seo-tag.
module RubyLlmDocumentCollectionSeo
  DOC_COLLECTIONS = %w[
    getting_started
    core_features
    advanced
    reference
  ].freeze

  def date
    return nil if docs_collection?

    super
  end

  private

  def docs_collection?
    @obj.respond_to?(:collection) && DOC_COLLECTIONS.include?(@obj.collection.label)
  end
end

Jekyll::Drops::DocumentDrop.prepend(RubyLlmDocumentCollectionSeo)
