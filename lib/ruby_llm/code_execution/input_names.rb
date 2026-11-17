# frozen_string_literal: true

module RubyLLM
  class CodeExecution
    # Names the conversation's files under +attachments/+ in the order they
    # arrived. The newest file of a name keeps it, as it would on a disk,
    # and the file that held it moves to a numbered name once and stays
    # there, so a name the model was told never points at another earlier
    # file. Names compare without case, for the filesystems that do, and
    # files with equal content share one.
    class InputNames # :nodoc:
      Move = Struct.new(:files, :from, :to)

      # Returns each named attachment's name, by identity.
      attr_reader :names

      def initialize
        @names = {}.compare_by_identity
        @holders = {}
        @folders = Set.new
      end

      # Names +attachment+ and returns the moves that made room for it.
      def add(attachment)
        return [] if attachment.provider_file? || @names.key?(attachment)

        name = Workspace.filename(attachment.filename)
        moves = clear_folders(name)
        holder = @holders[name.downcase]
        if holder && holder.last.first.content.b == attachment.content.b
          hold(holder.first, holder.last << attachment)
        else
          hold(name, [attachment])
          moves << relocate(holder) if holder
        end
        moves
      end

      private

      def hold(name, files)
        @holders[name.downcase] = [name, files]
        files.each { |file| @names[file] = name }
      end

      def relocate(holder)
        from, files = holder
        to = numbered_names(original_name(files)).find do |candidate|
          !@holders.key?(candidate.downcase) && !@folders.include?(candidate.downcase)
        end
        hold(to, files)
        Move.new(files, from, to)
      end

      # A numbered file gives way to a folder another input needs.
      def clear_folders(name)
        parts = name.downcase.split('/')
        folders = (1...parts.size).map { |size| parts.first(size).join('/') }
        @folders.merge(folders)
        folders.filter_map do |folder|
          holder = @holders[folder]
          next if holder.nil? || holder.first == original_name(holder.last)

          @holders.delete(folder)
          relocate(holder)
        end
      end

      def original_name(files)
        Workspace.filename(files.first.filename)
      end

      def numbered_names(name)
        extension = File.extname(name)
        stem = name.delete_suffix(extension)
        (2..).lazy.map { |number| "#{stem}-#{number}#{extension}" }
      end
    end
  end
end
