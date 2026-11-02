# frozen_string_literal: true

module RubyLLM
  module Sandbox
    # Rewrites a policy for Landlock, which grants whole directory trees
    # and cannot take part of one away. Each readable or writable path that
    # holds a denied one is replaced by the entries around it, down to the
    # denied path, so the policy hides the same paths without denying
    # anything inside a granted tree. Entries added later to a directory
    # granted entry by entry stay hidden. A writable path cannot be split
    # that way, since creating files needs the directory itself, so a
    # denied path inside one raises ConfigurationError. Paths compare by
    # where they really lead, since that is what Landlock grants.
    module Landlock # :nodoc:
      module_function

      def policy(sandbox)
        denied, readable, writable = [sandbox.denied, sandbox.readable, sandbox.writable].map do |paths|
          paths.map { |path| real(path) }
        end
        refuse_writable(writable, denied)
        sandbox.dup
               .with_readable(nil).with_readable(*around(readable, denied))
               .with_writable(nil).with_writable(*around(writable, denied))
               .with_denied(nil)
               .with_denied(*denied.reject { |path| (readable + writable).any? { |root| inside?(path, root) } })
               .with_backend(:landlock)
      end

      def refuse_writable(writable, denied)
        writable.each do |path|
          hidden = denied.find { |candidate| candidate != path && inside?(candidate, path) }
          next unless hidden

          raise ConfigurationError, "Landlock cannot hide #{hidden} inside the writable #{path}. " \
                                    'Leave it out of the writable path, or run on Bubblewrap'
        end
      end

      def around(paths, denied)
        paths.flat_map { |path| entries(path, denied) }.uniq
      end

      def entries(path, denied)
        return [] if hidden?(path, denied)

        return [path] if denied.none? { |hidden| inside?(hidden, path) }
        return [] unless File.directory?(path)

        Dir.children(path).sort.flat_map { |child| entries(File.join(path, child), denied) }
      end

      def hidden?(path, denied)
        denied.any? { |hidden| inside?(path, hidden) } || reaches?(path, denied)
      end

      def reaches?(path, denied)
        return false unless File.symlink?(path)

        target = File.realpath(path)
        denied.any? { |hidden| inside?(target, hidden) || inside?(hidden, target) }
      rescue SystemCallError
        true
      end

      def real(path)
        path = File.expand_path(path)
        File.realpath(path)
      rescue SystemCallError
        File.join(real(File.dirname(path)), File.basename(path))
      end

      def inside?(path, root)
        path == root || path.start_with?(File.join(root, ''))
      end
    end
  end
end
