# frozen_string_literal: true

require 'json'
require 'terminal-table'

def missing_provider_methods
  # Ensure the entire codebase is loaded
  require_relative '../../lib/ruby_llm'

  provider_classes = {}
  all_methods = []

  # Collect all public methods from each provider class
  RubyLLM::Providers.constants.each do |provider|
    provider_module = RubyLLM::Providers.const_get(provider)
    next unless provider_module.const_defined?(:Capabilities)

    capabilities_class = provider_module::Capabilities
    methods = capabilities_class.public_methods(false)
    provider_classes[provider] = methods
    all_methods.concat(methods)
    all_methods.sort!
  end

  all_methods.uniq!

  # Find methods that are present in all providers
  missing_methods = all_methods.reject do |method|
    provider_classes.values.all? { |methods| methods.include?(method) }
  end

  missing_methods.each_with_object({}) do |method, mms_hash|
    mms_hash[method] = provider_classes.keys.each_with_object({}) do |provider, mm_hash|
      mm_hash[provider] = provider_classes[provider].include?(method)
    end
  end
end

def missing_methods_markdown_string(missing_methods_info)
  # Get sorted list of all providers
  providers = missing_methods_info.values.flat_map { |p| p.keys }.uniq.sort

  markdown_string = "# Missing Methods in Providers\n\n"

  # Create header row with provider names
  markdown_string += "| Method | #{providers.join(' | ')} |\n"

  # Create alignment row
  markdown_string += "|--------|#{providers.map { ':-:' }.join('|')}|\n"

  # Create rows for each method
  missing_methods_info.each do |method, provider_info|
    row = providers.map { |provider| provider_info[provider] ? '✓' : '' }
    markdown_string += "| #{method} | #{row.join(' | ')} |\n"
  end

  markdown_string
end

def missing_methods_as_tty_table(missing_methods_info)
  missing_methods_info = missing_provider_methods
  providers = missing_methods_info.values.flat_map { |p| p.keys }.uniq.sort

  # Create the table with headers
  table = Terminal::Table.new do |t|
    # Add header row with provider names
    t.headings = ['Method', *providers]

    # Add rows for each method
    missing_methods_info.each do |method, provider_info|
      row = providers.map { |provider| provider_info[provider] ? '✅' : '❌' }
      t.add_row [method, *row]
    end

    # Style the table
    t.style = {
      border_x: '━',
      border_y: '┃',
      border_i: '╋',
      alignment: :center
    }
  end

  table
end

namespace :providers do
  desc 'Check method consistency across providers and output as JSON'
  task :missing_methods_as_json do
    puts JSON.pretty_generate(missing_provider_methods)
  end

  desc 'Check method consistency across providers and output as Markdown'
  task :missing_methods_as_markdown do
    puts missing_methods_markdown_string(missing_provider_methods)
  end

  desc 'Check method consistency across providers and output as tty table'
  task :missing_methods_as_tty_table do
    puts missing_methods_as_tty_table(missing_provider_methods)
  end
end

