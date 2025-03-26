# frozen_string_literal: true

require 'English'
require 'faraday'
require 'fileutils'
require 'nokogiri'
require 'ruby_llm'

# URLs to process
PROVIDER_DOCS = {
  openai: {
    models: 'https://platform.openai.com/docs/models',
    pricing: 'https://platform.openai.com/docs/pricing'
  },
  gemini: {
    models: 'https://ai.google.dev/gemini-api/docs/models/gemini',
    pricing: 'https://ai.google.dev/gemini-api/docs/pricing'
  },
  deepseek: {
    models: 'https://api-docs.deepseek.com/quick_start/pricing/'
  },
  anthropic: {
    models: 'https://docs.anthropic.com/en/docs/about-claude/models/all-models'
  }
}.freeze

def fetch_page(url) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
  if url.include?('openai.com')
    puts "Please visit #{url} and paste the content below (type 'END' on a new line when done):"
    original_separator = $INPUT_RECORD_SEPARATOR
    $/ = 'END'
    content = $stdin.gets&.chomp
    $/ = original_separator

    raise "No content provided for #{url}" unless content

    content
  else
    response = http_client.get(url)
    html = Nokogiri::HTML(response.body)

    # Remove script tags and comments
    html.css('script').remove
    html.xpath('//comment()').remove

    # Extract text content
    text = html.css('body').text

    # Clean up whitespace
    text.gsub!(/\s+/, ' ')
    text.strip!

    text
  end
rescue StandardError => e
  raise "Failed to fetch #{url}: #{e.message}"
end

def http_client
  @http_client ||= Faraday.new do |f|
    f.response :raise_error
    f.response :logger, RubyLLM.logger, { headers: false, bodies: true }
  end
end

namespace :models do # rubocop:disable Metrics/BlockLength
  desc 'Update available models from providers'
  task :update do
    # Configure API keys
    RubyLLM.configure do |config|
      config.openai_api_key = ENV.fetch('OPENAI_API_KEY', nil)
      config.anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY', nil)
      config.gemini_api_key = ENV.fetch('GEMINI_API_KEY', nil)
      config.deepseek_api_key = ENV.fetch('DEEPSEEK_API_KEY', nil)
    end

    models = RubyLLM.models.refresh!
    models.save_models

    puts "Updated models.json with #{models.all.size} models:"
    RubyLLM::Provider.providers.each do |provider_sym, provider_module|
      provider_name = provider_module.to_s.split('::').last
      provider_models = models.all.select { |m| m.provider == provider_sym.to_s }
      puts "#{provider_name} models: #{provider_models.size}"
    end
  end

  desc 'Update model capabilities modules by scraping provider documentation (use PROVIDER=name to update only one)'
  task :update_capabilities do # rubocop:disable Metrics/BlockLength
    # Check if a specific provider was requested
    target_provider = ENV['PROVIDER']&.to_sym

    # Configure API keys
    RubyLLM.configure do |config|
      config.openai_api_key = ENV.fetch('OPENAI_API_KEY')
      config.anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY')
      config.gemini_api_key = ENV.fetch('GEMINI_API_KEY')
    end

    # Filter providers if a specific one was requested
    providers_to_process = if target_provider && PROVIDER_DOCS.key?(target_provider)
                             { target_provider => PROVIDER_DOCS[target_provider] }
                           else
                             PROVIDER_DOCS
                           end

    # Process each provider
    providers_to_process.each do |provider, urls| # rubocop:disable Metrics/BlockLength
      puts "Processing #{provider}..."

      # Initialize our AI assistants
      #
      gemini = RubyLLM.chat(model: 'gemini-2.0-flash').with_temperature(0)
      claude = RubyLLM.chat(model: 'claude-3-7-sonnet-20250219').with_temperature(0)

      # Read existing capabilities file if present
      existing_file = "lib/ruby_llm/providers/#{provider}/capabilities.rb"
      existing_code = File.read(existing_file) if File.exist?(existing_file)

      begin
        # Download documentation
        docs = urls.map do |type, url|
          puts "  Getting #{type} documentation..."
          content = fetch_page(url)

          puts "\nHere's what I got:\n\n"
          puts "#{content.slice(0, 500)}...\n\n"

          loop do
            print 'Does this content look correct? (y/n): '
            answer = $stdin.gets&.chomp&.downcase
            break if answer == 'y'
            raise "Content verification failed for #{url}" if answer == 'n'
          end

          "#{type.to_s.upcase} DOCUMENTATION:\n\n#{content}"
        end.join("\n\n")

        # Extract relevant information with Gemini
        puts '  Extracting model information...'
        extraction_prompt = <<~PROMPT
          Extract relevant model capabilities information from this documentation:

          #{docs}

          Focus on:
          1. Available models and their IDs
          2. Context window sizes
          3. Maximum output tokens
          4. Pricing information
          5. Model capabilities (vision, function calling, etc)

          Format the information clearly and concisely, focusing only on facts about the models.
        PROMPT

        model_info = gemini.ask(extraction_prompt).content

        # Generate Ruby code with Claude
        puts '  Generating Ruby code...'
        code_prompt = <<~PROMPT
          I need you to generate a Ruby module for #{provider}'s model capabilities.
          Use this extracted model information:

          #{model_info}

          The module should go in lib/ruby_llm/providers/#{provider}/capabilities.rb and follow these conventions:

          1. Include methods for determining context windows, token limits, pricing, and capabilities
          2. Use consistent naming with other providers
          3. Include detailed pricing information in a PRICES constant
          4. Follow the existing structure in the codebase
          5. Use Ruby idioms and clean code practices
          6. Include module_function to make methods callable at module level
          7. Include all necessary method documentation

          Here's the existing implementation for reference (maintain similar structure and same method names):

          #{existing_code}

          Focus on accuracy and maintaining consistency with the existing codebase structure.
        PROMPT

        response = claude.ask(code_prompt)

        # Extract Ruby code from Claude's response
        puts "  Extracting Ruby code from Claude's response..."
        ruby_code = nil

        # Look for Ruby code block
        ruby_code = Regexp.last_match(1).strip if response.content =~ /```ruby\s*(.*?)```/m

        # Verify we found Ruby code
        raise "No Ruby code block found in Claude's response" if ruby_code.nil? || ruby_code.empty?

        # Save the file
        file_path = "lib/ruby_llm/providers/#{provider}/capabilities.rb"
        puts "  Writing #{file_path}..."

        FileUtils.mkdir_p(File.dirname(file_path))
        File.write(file_path, ruby_code)
      rescue StandardError => e
        raise "Failed to process #{provider}: #{e.message}"
      end
    end

    puts "Done! Don't forget to review the generated code and run the tests."
  end
end
