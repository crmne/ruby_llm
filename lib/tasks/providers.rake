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

  markdown_string = "# Provider Capability Methods' Presence/Absence\n\n"

  # Add legend
  markdown_string += "> **Legend**: ✔ = method is present\n\n"

  # Create header row with provider names and sequence numbers on both sides
  markdown_string += "| # | Method | #{providers.join(' | ')} | # |\n"

  # Create alignment row with added columns
  markdown_string += "|:-:|--------|#{providers.map { ':-:' }.join('|')}|:-:|\n"

  # Create rows for each method with sequence numbers on both sides
  missing_methods_info.each_with_index do |(method, provider_info), index|
    row_num = index + 1
    # Alternate between different symbols for even and odd rows for better readability
    check_mark = '✔'
    row = providers.map { |provider| provider_info[provider] ? check_mark : '' }
    
    markdown_string += "| #{row_num} | **#{method}** | #{row.join(' | ')} | #{row_num} |\n"
  end

  markdown_string
end

def missing_methods_as_tty_table(missing_methods_info)
  missing_methods_info = missing_provider_methods
  providers = missing_methods_info.values.flat_map { |p| p.keys }.uniq.sort

  # Create the table with headers
  table = Terminal::Table.new do |t|
    # Add header row with provider names
    t.headings = ['#', 'Method', *providers, '#']

    # Add rows for each method with row numbers
    missing_methods_info.each_with_index do |(method, provider_info), index|
      row_num = index + 1
      row = providers.map { |provider| provider_info[provider] ? '✅' : '❌' }
      t.add_row [row_num, method, *row, row_num]
    end

    # Style the table
    t.style = {
      border_x: '━',
      border_y: '┃',
      border_i: '╋',
      alignment: :center
    }
  end

  # Add legend below the table
  legend = "\nLegend: ✅ = method is present, ❌ = method is missing\n"
  
  "#{table}#{legend}"
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
