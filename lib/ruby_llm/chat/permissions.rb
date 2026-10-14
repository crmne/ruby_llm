# frozen_string_literal: true

require 'securerandom'

module RubyLLM
  class Chat
    # How Chat#with_permissions decides each tool call, and the grants a
    # chat collects: tools approved with <tt>remember: true</tt>, and the
    # hosts and paths its code was granted through +request_permission+.
    module Permissions # :nodoc:
      MODES = %i[read_only ask auto dangerous].freeze
      SANDBOX_GRANTS = %w[network readable writable].freeze
      GRANTS = (%w[tools] + SANDBOX_GRANTS).freeze
      DEFAULT_PORTS = %w[80 443].freeze
      ENVIRONMENT_ID = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

      class << self
        def mode(value)
          return if value.nil?

          mode = value.to_s.to_sym
          return mode if MODES.include?(mode)

          raise ArgumentError, "permissions must be #{MODES.map(&:inspect).join(', ')}, or nil, got #{value.inspect}"
        end

        def allow(entries, mode)
          entries = entries.is_a?(Array) ? entries.flatten.compact : [entries].compact
          allow = { tools: [], servers: [], network: [], readable: [], writable: [] }
          return allow if entries.empty?
          raise ArgumentError, 'allow: applies to :auto permissions' unless mode == :auto

          entries.each { |entry| add_allowed(allow, entry) }
          allow.transform_values { |values| values.uniq.freeze }.freeze
        end

        def grants(value)
          value = value.to_h.transform_keys(&:to_s)
          grants = GRANTS.to_h { |key| [key, Array(value[key]).map(&:to_s).uniq] }
          environment = value['environment'].to_s
          grants['environment'] = environment if environment.match?(ENVIRONMENT_ID)
          grants
        end

        def merge_grants(current, additions)
          grants = grants(current)
          additions = grants(additions)
          GRANTS.each { |key| grants[key] = (grants[key] + additions[key]).uniq }
          grants['environment'] ||= SecureRandom.uuid if grants['network'].any?
          grants
        end

        def host(target)
          host = target.to_s.strip.downcase
          name, port = host.split(':', 2)
          valid = name.match?(/\A[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+\z/) &&
                  (port.nil? || port.match?(/\A[1-9]\d{0,4}\z/))
          raise ArgumentError, "#{target.inspect} is not a host name such as pypi.org" unless valid

          DEFAULT_PORTS.include?(port) ? name : host
        end

        def path(target)
          path = target.to_s
          unless path.start_with?('/') || path.match?(%r{\A[A-Za-z]:[\\/]})
            raise ArgumentError, "#{target.inspect} is not an absolute path"
          end
          raise ArgumentError, "#{target.inspect} does not exist" unless File.exist?(path)

          real = File.realpath(path)
          raise ArgumentError, 'Access to the whole file system cannot be granted' if File.dirname(real) == real

          real
        end

        def covers_host?(allowed, host)
          return true if allowed == host || allowed == host.split(':', 2).first

          allowed.start_with?('*.') && !host.include?(':') && host.end_with?(allowed.delete_prefix('*'))
        end

        def covers_path?(allowed, path)
          path == allowed || path.start_with?(File.join(allowed, ''))
        end

        private

        def add_allowed(allow, entry)
          case entry
          when Hash then add_sandbox_allowed(allow, entry)
          when Class then add_allowed_class(allow, entry)
          when RubyLLM::MCP then allow[:servers] << entry.name.to_s
          when RubyLLM::Tool then allow[:tools] << entry.name.to_s
          when String, Symbol then allow[:tools] << entry.to_s
          else raise ArgumentError,
                     "allow: takes tools, tool names, MCP servers, and sandbox grants, got #{entry.inspect}"
          end
        end

        def add_allowed_class(allow, entry)
          if entry <= RubyLLM::MCP
            allow[:servers] << entry.default_name.to_s
          elsif entry <= RubyLLM::Tool
            allow[:tools] << entry.tool_name.to_s
          else
            raise ArgumentError, "allow: takes Tool and MCP classes, got #{entry.inspect}"
          end
        end

        def add_sandbox_allowed(allow, entry)
          entry.each do |kind, targets|
            kind = kind.to_s
            unless SANDBOX_GRANTS.include?(kind)
              raise ArgumentError, "allow: grants #{SANDBOX_GRANTS.join(', ')}, got #{kind.inspect}"
            end

            allow[kind.to_sym].concat(Array(targets).map { |target| allowed_target(kind, target) })
          end
        end

        def allowed_target(kind, target)
          return target.to_s.strip.downcase if kind == 'network'

          path = File.expand_path(target.to_s)
          File.exist?(path) ? File.realpath(path) : path
        end
      end

      private

      def permissions_mode
        refresh_permissions
        @permissions
      end

      def refresh_permissions
        stored = @permissions_checker&.call
        return unless stored

        @permissions = Permissions.mode(stored[:mode])
        @permission_grants = Permissions.grants(stored[:grants])
      end

      def permission_decision(tool, tool_call, mode)
        return sandbox_request_decision(tool_call, mode) if permission_request?(tool)

        case mode
        when :dangerous then recorded_decision(tool_call) != false
        when :read_only then read_only_decision(tool, tool_call)
        when :ask, :auto then asking_decision(tool, tool_call, mode)
        end
      end

      def permission_request?(tool)
        !@permission_request_tool.nil? && tool.equal?(@permission_request_tool)
      end

      def read_only_decision(tool, tool_call)
        return false unless tool.nil? || tool.read_only?

        tool&.requires_approval? ? approval_decision(tool, tool_call) : @tool_call_decisions[tool_call.id] != false
      end

      def asking_decision(tool, tool_call, mode)
        return approval_decision(tool, tool_call) if tool&.requires_approval?
        return @tool_call_decisions[tool_call.id] != false if tool.nil? || tool.read_only?
        return @tool_call_decisions[tool_call.id] != false if mode == :auto && allowed_tool?(tool)

        approval_decision(tool, tool_call)
      end

      def remote_permission_decision(tool_call)
        case permissions_mode
        when :dangerous then recorded_decision(tool_call) != false
        when :read_only then false
        when :auto
          allowed = @permission_allow[:tools].include?(tool_call.name)
          allowed ? recorded_decision(tool_call) != false : approval_decision(nil, tool_call)
        else approval_decision(nil, tool_call)
        end
      end

      def sandbox_request_decision(tool_call, mode)
        return false if mode == :read_only
        return recorded_decision(tool_call) != false if mode == :dangerous

        kind, targets = @permission_request_tool.request(tool_call.arguments)
        return @tool_call_decisions[tool_call.id] != false unless kind
        return recorded_decision(tool_call) != false if granted?(kind, targets)
        return recorded_decision(tool_call) != false if mode == :auto && allowed_request?(kind, targets)

        tool_call_approval(nil, tool_call)
      end

      def approval_decision(tool, tool_call)
        decision = tool_call_approval(tool, tool_call)
        return decision unless decision.nil?

        true if @permission_grants['tools'].include?(tool_call.name)
      end

      def recorded_decision(tool_call)
        return @tool_call_decisions[tool_call.id] if @tool_call_decisions.key?(tool_call.id)

        @approval_checker&.call(tool_call)
      end

      def allowed_tool?(tool)
        return true if @permission_allow[:tools].include?(tool.name.to_s)
        return false if @permission_allow[:servers].empty?

        mcp.any? do |server|
          @permission_allow[:servers].include?(server.name.to_s) && server.tools.any? { |offered| offered.equal?(tool) }
        end
      end

      def granted?(kind, targets)
        granted = @permission_grants[kind]
        targets.all? { |target| granted.any? { |grant| covers?(kind, grant, target) } }
      end

      def allowed_request?(kind, targets)
        allowed = @permission_allow[kind.to_sym]
        targets.all? { |target| allowed.any? { |entry| covers?(kind, entry, target) } }
      end

      def covers?(kind, allowed, target)
        kind == 'network' ? Permissions.covers_host?(allowed, target) : Permissions.covers_path?(allowed, target)
      end

      def remember_tool_call(tool_call)
        id = tool_call.respond_to?(:id) ? tool_call.id : tool_call
        call = tool_call.respond_to?(:name) ? tool_call : find_tool_call(id)
        raise ArgumentError, "Unknown tool call: #{id.inspect}" unless call
        return if permission_request?(tools[call.name.to_sym])

        record_permission_grants('tools' => [call.name])
      end

      def find_tool_call(id)
        messages.reverse_each do |message|
          call = message.tool_calls&.[](id)
          return call if call
        end
        nil
      end

      def grant_sandbox_access(kind, targets)
        record_permission_grants(kind => targets)
      end

      def record_permission_grants(additions)
        stored = @permission_recorder&.call(additions)
        @permission_grants = if stored
                               Permissions.grants(stored)
                             else
                               Permissions.merge_grants(@permission_grants,
                                                        additions)
                             end
      end

      def sandbox_grants
        refresh_permissions
        grants = @permission_grants
        { network: grants['network'], readable: grants['readable'], writable: grants['writable'],
          environment: grants['environment'] }
      end
    end
  end
end
