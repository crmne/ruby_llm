# frozen_string_literal: true

require 'ruby_llm'
require 'json'
require_relative 'code_validator'

class CapabilityGenerator # rubocop:disable Style/Documentation
  def initialize(provider_name, docs_html)
    @provider_name = provider_name
    @docs_html = docs_html
    @processed_html = process_html(docs_html)
  end

  def generate_and_save # rubocop:disable Metrics/MethodLength
    puts "  Starting code generation for #{@provider_name}..."

    existing_path = File.expand_path("../../lib/ruby_llm/providers/#{@provider_name}/capabilities.rb", __dir__)
    unless File.exist?(existing_path)
      puts "  Skipping: No file at #{existing_path}"
      return
    end

    existing_code = File.read(existing_path)
    puts '  Read existing code'

    generated_code = generate_capabilities(existing_code)

    if generated_code
      puts "  Writing updated code to #{existing_path}..."
      File.write(existing_path, generated_code)
      puts "  Updated #{@provider_name}"

      verify_code_with_models_update
    else
      puts "  Failed to generate valid code for #{@provider_name}"
    end
  end

  private

  def process_html(docs_html) # rubocop:disable Metrics/MethodLength
    docs_html.transform_values do |html|
      next '' if html.nil? || html.empty?

      # Extract just the main content areas, skip scripts, styles, etc
      main_content = html.scan(%r{<main.*?>.*?</main>}m).first ||
                     html.scan(%r{<article.*?>.*?</article>}m).first ||
                     html.scan(%r{<div class="content.*?>.*?</div>}m).first

      if main_content
        # Further clean up the content
        main_content.gsub(%r{<script.*?>.*?</script>}m, '')
                    .gsub(%r{<style.*?>.*?</style>}m, '')
                    .gsub(/<!--.*?-->/m, '')
                    .gsub(/\s+/, ' ')
                    .strip
      else
        ''
      end
    end
  end

  def generate_capabilities(existing_code) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    max_retries = 3
    retries = 0

    loop do # rubocop:disable Metrics/BlockLength
      puts "  Attempt #{retries + 1}/#{max_retries}..."

      begin
        gemini = RubyLLM.chat(model: 'gemini-1.5-pro-latest')
                        .with_temperature(0.1)

        docs_json = JSON.pretty_generate(@processed_html)

        prompt = <<~PROMPT
          Update RubyLLM::Providers::#{@provider_name.capitalize}::Capabilities module.
          Only use the provided HTML content and existing code structure.
          Focus on updating values while preserving the module structure.

          Existing code to maintain structure:
          ```ruby
          #{existing_code}
          ```

          HTML content to extract new values from:
          ```json
          #{docs_json}
          ```

          Return ONLY the complete Ruby code within ```ruby ``` tags.
        PROMPT

        response = gemini.ask(prompt)
        generated_code = CodeValidator.extract_code_from_response(response.content)

        return generated_code if generated_code && CodeValidator.validate_syntax(generated_code)
      rescue RubyLLM::BadRequestError => e
        puts "  Error: #{e.message}"
        # Try with even less content if we hit token limits
        @processed_html = @processed_html.transform_values { |html| html[0..10_000] }
      rescue StandardError => e
        puts "  Error: #{e.class} - #{e.message}"
      end

      retries += 1
      break if retries >= max_retries
    end

    nil
  end

  def verify_code_with_models_update
    puts '  Verifying with models:update...'
    begin
      Rake::Task['models:update'].reenable
      Rake::Task['models:update'].invoke
      puts '  Verification successful'
    rescue StandardError => e
      puts "  Verification failed: #{e.message}"
    end
  end
end
