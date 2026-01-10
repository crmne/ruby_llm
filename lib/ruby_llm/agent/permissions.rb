# frozen_string_literal: true

module RubyLLM
  class Agent
    # Permission system for controlling tool access
    #
    # Example:
    #   permissions = Permissions.new
    #   permissions.mode = :allow_list
    #   permissions.allow('Read', 'Glob', 'Grep')
    #   permissions.deny('Bash')
    class Permissions
      attr_accessor :mode, :denial_reason

      MODES = %i[allow_all deny_all allow_list deny_list ask].freeze

      def initialize
        @mode = :allow_all
        @allowed = []
        @denied = []
        @callbacks = {}
        @denial_reason = nil
      end

      # Add tools to allow list
      #
      # @param tools [Array<String>] Tool names
      # @return [self]
      def allow(*tools)
        @allowed.concat(tools.flatten.map(&:to_s))
        self
      end

      # Add tools to deny list
      #
      # @param tools [Array<String>] Tool names
      # @return [self]
      def deny(*tools)
        @denied.concat(tools.flatten.map(&:to_s))
        self
      end

      # Register a permission callback for a tool
      #
      # @param tool_name [String] Tool name
      # @yield [arguments] Called to check permission
      # @yieldreturn [Boolean] true to allow, false to deny
      def on(tool_name, &block)
        @callbacks[tool_name.to_s] = block
        self
      end

      # Check if a tool is allowed
      #
      # @param tool_name [String] Tool name
      # @param arguments [Hash] Tool arguments
      # @return [Boolean]
      def allowed?(tool_name, arguments = {})
        @denial_reason = nil
        name = tool_name.to_s

        # Check explicit deny list first
        if @denied.include?(name)
          @denial_reason = "Tool '#{name}' is explicitly denied"
          return false
        end

        # Check custom callback
        if @callbacks[name]
          result = @callbacks[name].call(arguments)
          unless result
            @denial_reason = "Tool '#{name}' denied by permission callback"
            return false
          end
          return true
        end

        case @mode
        when :allow_all
          true
        when :deny_all
          @denial_reason = "All tools denied (mode: deny_all)"
          false
        when :allow_list
          allowed = @allowed.include?(name)
          @denial_reason = "Tool '#{name}' not in allow list" unless allowed
          allowed
        when :deny_list
          allowed = !@denied.include?(name)
          @denial_reason = "Tool '#{name}' in deny list" unless allowed
          allowed
        when :ask
          @denial_reason = "Permission mode is :ask - requires manual approval"
          false # Caller should handle asking
        else
          true
        end
      end
    end
  end
end
