# frozen_string_literal: true

require 'ruby_llm'
require 'uri'
require_relative 'browser_helper'
require_relative 'cli_helper'

class CapabilityScraper # rubocop:disable Metrics/ClassLength,Style/Documentation
  PROVIDER_DOCS = {
    openai: {
      url: 'https://platform.openai.com/docs/models'
    },
    anthropic: {
      url: 'https://docs.anthropic.com/claude/docs/models-overview'
    },
    gemini: {
      url: 'https://ai.google.dev/models/gemini',
      pricing_url: 'https://ai.google.dev/pricing'
    },
    deepseek: {
      url: 'https://api-docs.deepseek.com/quick_start/pricing'
    }
  }.freeze

  def self.parse_providers(providers_arg) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
    provider_input = (providers_arg || '').downcase.split(',').map(&:strip).reject(&:empty?)

    target_providers = if provider_input.empty? || provider_input.include?('all')
                         PROVIDER_DOCS.keys
                       else
                         provider_input.map(&:to_sym).select { |p| PROVIDER_DOCS.key?(p) }
                       end

    if target_providers.empty?
      puts "No valid providers. Available: all, #{PROVIDER_DOCS.keys.join(', ')}"
      exit(1)
    end

    puts "Targeting providers: #{target_providers.join(', ')}"
    target_providers
  end

  def initialize(providers)
    @providers = providers
    @browser_helper = BrowserHelper.new
  end

  def run # rubocop:disable Metrics/MethodLength
    @providers.each do |provider_sym|
      provider_name = provider_sym.to_s
      puts "\n======== Processing Provider: #{provider_name.upcase} =========="

      docs_info = PROVIDER_DOCS[provider_sym]
      docs_html = scrape_provider(provider_sym, docs_info)

      next unless docs_html.any? { |_k, v| v && !v.strip.empty? }

      summarize_html_data(docs_html)
      yield(provider_name, docs_html) if block_given?
    end
  ensure
    @browser_helper&.close
  end

  private

  def scrape_provider(provider_sym, docs_info)
    if provider_sym == :openai
      handle_openai_scraping(docs_info[:url])
    else
      handle_standard_scraping(provider_sym, docs_info)
    end
  end

  def handle_openai_scraping(main_url) # rubocop:disable Metrics/MethodLength
    main_url_path = extract_path_from_url(main_url)
    overview_key = generate_key_from_url(main_url, main_url_path)
    docs_html = {}

    puts "\n--- Interactive Scraping for OpenAI ---"
    puts "  Navigating to main OpenAI models page: #{main_url}..."

    begin
      @browser_helper.goto(main_url)
      return docs_html unless @browser_helper.wait_for_page_load

      puts '  Scraping overview page HTML...'
      overview_html = @browser_helper.get_page_content('OpenAI Overview')
      docs_html[overview_key] = overview_html if overview_html && !overview_html.empty?

      # Interactive scraping loop
      interactive_scraping_loop(docs_html, main_url, main_url_path, overview_key)
    rescue StandardError => e
      puts "FATAL: Navigation failed: #{e}"
    end

    docs_html
  end

  def interactive_scraping_loop(docs_html, main_url, main_url_path, overview_key) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    loop do # rubocop:disable Metrics/BlockLength
      current_url = begin
        @browser_helper.current_url
      rescue StandardError
        'N/A'
      end
      puts "\n--- OpenAI Subpage Scraping ---"
      puts "Current URL: #{current_url}"
      puts "Collected Keys: #{docs_html.keys.sort.join(', ')}"
      puts '---------------------------------'

      puts 'Ready to scrape current page. Options:'
      puts 's: Scrape current page'
      puts 'b: Back to overview'
      puts 'q: Quit scraping'

      choice = CliHelper.get_user_choice('Choose action', %w[s b q])

      case choice
      when 's'
        scrape_current_page(docs_html, main_url_path, overview_key)
      when 'b'
        puts "  Navigating back to overview: #{main_url}..."
        begin
          @browser_helper.goto(main_url)
          @browser_helper.wait_for_page_load
        rescue StandardError => e
          puts "  Error navigating back: #{e.message}. Navigate manually."
        end
      when 'q'
        puts '  Finished OpenAI scraping.'
        break
      end
    end
  end

  def scrape_current_page(docs_html, main_url_path, overview_key) # rubocop:disable Metrics/MethodLength
    current_url = begin
      @browser_helper.current_url
    rescue StandardError
      'N/A'
    end
    puts "  Scraping content from: #{current_url}"
    page_html = @browser_helper.get_page_content(current_url)

    if page_html && !page_html.empty?
      page_key = generate_key_from_url(current_url, main_url_path)
      if page_key != overview_key || !docs_html.key?(overview_key)
        docs_html[page_key] = page_html
        puts "  Stored HTML under key: #{page_key}"
      else
        puts '  Note: Back on overview page, skipping.'
      end
    end

    next_choice = CliHelper.get_user_choice('Continue? (y: scrape another, n: quit)', %w[y n])
    false if next_choice == 'n'
  end

  def handle_standard_scraping(provider, info)
    provider_name = provider.to_s
    docs_html = {}

    puts "\n--- Standard Scraping for #{provider_name.upcase} ---"

    # Main page scraping
    scrape_url(provider_name, info[:url], "#{provider_name}_main_html", docs_html)

    # Pricing page scraping (if available)
    if info[:pricing_url] && info[:pricing_url] != info[:url]
      scrape_url(provider_name, info[:pricing_url], "#{provider_name}_pricing_html", docs_html)
    end

    docs_html
  end

  def scrape_url(provider_name, url, key_name, docs_html)
    puts "  Scraping #{key_name}: #{url}..."

    begin
      @browser_helper.goto(url)
      return unless @browser_helper.wait_for_page_load

      html_content = @browser_helper.get_page_content("#{provider_name} #{key_name}")
      docs_html[key_name] = html_content if html_content && !html_content.empty?
    rescue StandardError => e
      puts "  Error on #{key_name}: #{e.message}"
    end
  end

  def extract_path_from_url(url_string)
    URI(url_string).path
  rescue StandardError
    '/docs/models'
  end

  def generate_key_from_url(url_string, base_url_path = '/docs/models')
    uri = URI(url_string)
    path = uri.path.chomp('/')
    return 'models_overview_html' if path == base_url_path

    key_part = path.split('/').reject(&:empty?).last || 'unknown'
    "model_#{key_part.gsub(/[^a-z0-9_\-]/i, '_')}_html"
  rescue StandardError => e
    puts "    Warning: URL parsing failed for: #{url_string} (#{e.message})"
    "scrape_#{Time.now.to_i}_html"
  end

  def summarize_html_data(docs_html) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
    docs_summary = docs_html.map do |k, v|
      desc = if v.nil? || v.strip.empty?
               '(Empty)'
             elsif v.include?('challenge') || v.include?('Checking')
               '(Challenge?)'
             else
               '(OK)'
             end
      "#{k}: ~#{v&.length || 0} chars #{desc}"
    end.join(', ')

    puts "\n  HTML Summary: #{docs_summary}"
    puts '  Warning: LLM results may be inaccurate.' if docs_summary.include?('(Challenge?)')
  end
end
