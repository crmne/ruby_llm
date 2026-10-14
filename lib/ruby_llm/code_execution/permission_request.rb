# frozen_string_literal: true

module RubyLLM
  class CodeExecution
    # The +request_permission+ tool a chat with code execution and a
    # permissions mode gives the model. The model names a network host or a
    # path on this machine and says why; running the call grants exactly
    # that to later +run_code+ calls in the chat. Chat#with_permissions
    # decides whether the call runs, waits for a decision, or is denied.
    class PermissionRequest < Tool # :nodoc:
      PERMISSIONS = %w[network readable writable].freeze
      ACCESS = { 'network' => 'network access to', 'readable' => 'read access to',
                 'writable' => 'write access to' }.freeze
      MAX_TARGETS = 10

      def self.tool_name
        'request_permission'
      end

      def initialize(grant)
        super()
        @grant = grant
      end

      def description
        [
          'Asks the user to let later run_code calls reach a network host, or read or write a path on this ' \
          'machine, that they cannot reach yet.',
          'Name each host exactly, without a scheme or path, such as pypi.org, and add a port only when it is not ' \
          '80 or 443. Wildcards are refused. Name paths as absolute paths.',
          'Explain in reason what the access is for: the user reads it before deciding.',
          'Installing packages needs their registry: rubygems.org for gem install, pypi.org and ' \
          'files.pythonhosted.org for pip install. Packages you install stay available for the rest of the ' \
          'conversation.'
        ].join(' ')
      end

      def parameters_schema
        {
          'type' => 'object',
          'properties' => {
            'permission' => { 'type' => 'string', 'enum' => PERMISSIONS,
                              'description' => 'network to reach hosts, readable or writable for paths' },
            'targets' => { 'type' => 'array', 'items' => { 'type' => 'string' },
                           'description' => 'The exact hosts or absolute paths' },
            'reason' => { 'type' => 'string', 'description' => 'Why the code needs this access' }
          },
          'required' => %w[permission targets reason],
          'additionalProperties' => false,
          'strict' => true
        }
      end

      # Returns the permission and normalized targets +arguments+ ask for,
      # or +nil+ when they are invalid.
      def request(arguments)
        parse(arguments['permission'] || arguments[:permission], arguments['targets'] || arguments[:targets])
      rescue ArgumentError
        nil
      end

      def execute(permission:, targets:, reason:) # rubocop:disable Lint/UnusedMethodArgument
        kind, targets = parse(permission, targets)
        @grant.call(kind, targets)
        "Granted #{ACCESS.fetch(kind)} #{targets.join(', ')} for the rest of the conversation. Run your code again."
      rescue ArgumentError => e
        { error: e.message }
      end

      private

      def parse(permission, targets)
        permission = permission.to_s
        unless PERMISSIONS.include?(permission)
          raise ArgumentError, "permission must be one of #{PERMISSIONS.join(', ')}, got #{permission.inspect}"
        end

        targets = Array(targets)
        raise ArgumentError, 'Name at least one target' if targets.empty?
        raise ArgumentError, "Ask for at most #{MAX_TARGETS} targets at a time" if targets.size > MAX_TARGETS

        [permission, targets.map { |target| normalize(permission, target) }.uniq]
      end

      def normalize(permission, target)
        permission == 'network' ? Chat::Permissions.host(target) : Chat::Permissions.path(target)
      end
    end
  end
end
