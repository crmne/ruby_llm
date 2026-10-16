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
          paths = @entry.skills.empty? ? ['skills'] : @entry.skills
          paths.flat_map do |path|
            folder = inside(plugin, path)
            next [] unless folder.directory?

            skill?(folder) ? [folder] : folder.children.select { |child| skill?(child) }
          end.uniq(&:basename).sort
        end

        def skill?(folder)
          file = folder.join(FILE)
          !folder.symlink? && file.file? && !file.symlink?
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
            FileUtils.cp(file, copy)
            copy.chmod(0o755) if file.executable?
          end
          target
        end
      end
    end
  end
end
