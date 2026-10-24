# frozen_string_literal: true

module RubyLLM
  module Protocols
    class ChatCompletions
      # Content filter verdicts as Azure reports them beside a completion:
      # prompt_filter_results and each choice's content_filter_results on
      # Chat Completions, a content_filters list on the Responses API.
      # Each category is an object with filtered and either a severity or
      # detected.
      module ContentFilters
        module_function

        def parse_content_filters(data)
          prompt = Array(data['prompt_filter_results']).flat_map do |result|
            parse_filter_results(result['content_filter_results'], :prompt)
          end
          completion = parse_filter_results(data.dig('choices', 0, 'content_filter_results'), :completion)
          listed = Array(data['content_filters']).flat_map do |result|
            parse_filter_results(result['content_filter_results'], result['source_type'])
          end
          prompt + completion + listed
        end

        def parse_filter_results(results, source)
          return [] unless results.is_a?(Hash) && ContentFilter::SOURCES.include?(source&.to_sym)

          results.filter_map do |category, verdict|
            next unless verdict.is_a?(Hash) && verdict.key?('filtered')

            ContentFilter.new(source:, category:, severity: verdict['severity'], filtered: verdict['filtered'],
                              detected: verdict['detected'])
          end
        end
      end
    end
  end
end
