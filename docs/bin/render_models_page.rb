#!/usr/bin/env ruby
# frozen_string_literal: true

# Render a version's Available Models page from the live registry with that
# version's own library and page template. Models from providers the version
# does not ship are left out, since it cannot call them.
#   render_models_page.rb SOURCE_ROOT REGISTRY_FILE OUTPUT_FILE

source, registry, output = ARGV
abort 'usage: render_models_page.rb SOURCE_ROOT REGISTRY_FILE OUTPUT_FILE' unless output

$LOAD_PATH.unshift File.join(source, 'lib')
require 'ruby_llm'
require File.join(source, 'tasks/support/model_catalog_page')

RubyLLM.models.load_from_json(registry)
models = RubyLLM.models.all.select { |model| RubyLLM::Provider.providers.key?(model.provider.to_sym) }
File.write(output, ModelCatalogPage.new(models).render)
puts "Rendered #{output} from #{registry}"
