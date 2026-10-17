# frozen_string_literal: true

module RubyLLM
  module Sandbox
    # Rewrites a policy for Landlock, which grants whole directory trees
    # and cannot take part of one away. Each readable or writable path that
    # holds a denied one is replaced by the entries around it, down to the
    # denied path, so the policy hides the same paths without denying
    # anything inside a granted tree. Entries added later to a directory
    # granted entry by entry stay hidden.
    module Landlock # :nodoc:
      module_function

      def policy(sandbox)
        denied = sandbox.denied.map { |path| File.expand_path(path) }
        granted = [*sandbox.readable, *sandbox.writable].map { |path| File.expand_path(path) }
        options = {
          readable: around(sandbox.readable, denied), writable: around(sandbox.writable, denied),
          denied: denied.reject { |path| granted.any? { |root| inside?(path, root) } },
          network: sandbox.network, env: sandbox.env, directory: sandbox.directory, timeout: sandbox.timeout,
          limits: sandbox.limits, priority: sandbox.priority, backend: :landlock
        }
        ::MXC::Sandbox.new(**options.compact)
      end

      def around(paths, denied)
        paths.flat_map { |path| entries(File.expand_path(path), denied) }.uniq
      end

      def entries(path, denied)
        return [] if hidden?(path, denied)

        inner = denied.select { |hidden| inside?(hidden, path) }
        return [path] if inner.empty?
        return [] unless File.directory?(path) && !File.symlink?(path)

        Dir.children(path).sort.flat_map { |child| entries(File.join(path, child), inner) }
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

      def inside?(path, root)
        path == root || path.start_with?(File.join(root, ''))
      end
    end
  end
end
