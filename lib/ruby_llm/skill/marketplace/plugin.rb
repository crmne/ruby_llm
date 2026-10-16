# frozen_string_literal: true

require 'fileutils'

module RubyLLM
  class Skill
    class Marketplace
      # One plugin of a marketplace being added: finds its skill folders in
      # the marketplace or in the plugin's own repository, and copies them.
      class Plugin # :nodoc:
        def initialize(entry, marketplace)
          @entry = entry
          @marketplace = marketplace
        end

        def copy_to(target, strict:)
          checkout do |directory|
            folders = skill_folders(inside(directory, @entry.path))
            raise InvalidMarketplaceError, "The #{@entry.name} plugin has no skills" if strict && folders.empty?

            folders.each { |folder| Skill.new(copy(folder, target.join(folder.basename))) }
          end
        end

        private

        def checkout(&)
          return yield @marketplace unless @entry.repository

          Repository.new(@entry.repository).checkout(&)
        end

        def skill_folders(plugin)
          ['skills', *@entry.skills].flat_map do |path|
            folder = inside(plugin, path)
            next [] unless folder.directory?

            next [folder] if folder.join(FILE).file?

            folder.children.select { |child| !child.symlink? && child.join(FILE).file? }
          end.uniq(&:basename).sort
        end

        def inside(directory, path)
          resolved = directory.join(path).expand_path
          resolved = resolved.realpath if resolved.exist?
          return resolved if resolved == directory || resolved.to_s.start_with?(File.join(directory.to_s, ''))

          raise InvalidMarketplaceError, "The #{@entry.name} plugin points outside its repository, to #{path}"
        end

        def copy(folder, target)
          folder.find do |file|
            next if file.symlink? || !file.file?

            copy = target.join(file.relative_path_from(folder))
            copy.dirname.mkpath
            FileUtils.cp(file, copy, preserve: true)
          end
          target
        end
      end
    end
  end
end
