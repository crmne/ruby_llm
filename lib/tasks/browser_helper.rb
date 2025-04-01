# frozen_string_literal: true

require 'ferrum'
require_relative 'cli_helper'

class BrowserHelper # rubocop:disable Style/Documentation
  REALISTIC_USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36' # rubocop:disable Layout/LineLength

  def initialize
    @browser = create_browser
  end

  def goto(url)
    @browser.goto(url)
  end

  def current_url
    @browser.page.url
  rescue StandardError
    'N/A'
  end

  def get_page_content(context = 'current page') # rubocop:disable Metrics/MethodLength
    puts "    Extracting HTML for #{context}..."

    begin
      sleep(1.0) # Small delay for page stability
      html = @browser.body

      if html && !html.empty?
        puts "      Extracted ~#{html.length} chars of HTML"
        puts '      WARNING: Challenge page detected' if html.match?(/challenge-platform|Checking site/)
        html
      else
        puts '      Warning: Empty content returned'
        ''
      end
    rescue StandardError => e
      puts "      Error getting HTML: #{e.class} - #{e.message}"
      ''
    end
  end

  def wait_for_page_load
    handle_cloudflare_challenge
  end

  def close
    puts "\nClosing browser..."
    @browser.quit
  rescue StandardError => e
    puts "  Warning: Error closing browser: #{e.message}"
  end

  private

  def create_browser
    puts '  Initializing browser for manual interaction...'

    Ferrum::Browser.new(
      window_size: [1366, 768],
      headless: false,
      browser_options: browser_options,
      timeout: 120,
      process_timeout: 120,
      pending_connection_errors: false
    )
  end

  def browser_options
    {
      'user-agent' => REALISTIC_USER_AGENT,
      'disable-gpu' => nil,
      'no-sandbox' => nil,
      'disable-blink-features' => 'AutomationControlled',
      'disable-infobars' => nil,
      'start-maximized' => nil
    }
  end

  def handle_cloudflare_challenge # rubocop:disable Metrics/MethodLength
    puts "\nWaiting for Cloudflare challenge resolution..."
    puts 'c: Challenge solved'
    puts 'q: Quit/Skip'

    choice = CliHelper.get_user_choice('Confirm when ready', %w[c q])
    return false if choice == 'q'

    begin
      @browser.page.target_id
      true
    rescue StandardError
      puts 'Browser check failed after challenge'
      false
    end
  end
end
