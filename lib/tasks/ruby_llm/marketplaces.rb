# frozen_string_literal: true

module RubyLLM
  module Tasks
    module Marketplaces # :nodoc:
      module_function

      def list
        Skill::Marketplace.all.each do |marketplace|
          puts "#{marketplace.name} (#{marketplace.source}): #{marketplace.skills.map(&:name).join(', ')}"
        end
      end

      def add(source, plugins)
        marketplace = Skill::Marketplace.add(source, only: (plugins unless plugins.empty?))
        puts "Added #{marketplace.skills.size} skills to #{marketplace.path}"
      end

      def update(name = nil)
        (name ? [Skill::Marketplace.find(name)] : Skill::Marketplace.all).each do |marketplace|
          marketplace.update
          puts "Updated #{marketplace.name} to #{marketplace.commit || marketplace.source}"
        end
      end

      def remove(name)
        puts "Removed #{Skill::Marketplace.find(name).remove.path}"
      end
    end
  end
end
