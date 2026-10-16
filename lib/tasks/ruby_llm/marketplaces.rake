# frozen_string_literal: true

namespace :ruby_llm do
  marketplaces = lambda do
    require 'ruby_llm'
    require 'tasks/ruby_llm/marketplaces'
    RubyLLM::Tasks::Marketplaces
  end

  desc 'List the plugin marketplaces in vendor/skills'
  task(:marketplaces) { marketplaces.call.list }

  namespace :marketplaces do
    desc 'Copy the skills of a plugin marketplace into vendor/skills (optionally only the named plugins)'
    task(:add, [:source]) { |_task, args| marketplaces.call.add(args.fetch(:source), args.extras) }

    desc 'Fetch a marketplace again (or every marketplace) and replace its skills'
    task(:update, [:name]) { |_task, args| marketplaces.call.update(args[:name]) }

    desc 'Delete a marketplace and its skills from vendor/skills'
    task(:remove, [:name]) { |_task, args| marketplaces.call.remove(args.fetch(:name)) }
  end
end
