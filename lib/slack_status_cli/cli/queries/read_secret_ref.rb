require "open3"

module SlackStatusCli
  module Cli
    module Queries
      # Resolves a `secret:<scheme>:<locator>` reference to its plaintext value,
      # leaving any non-`secret:` value untouched so callers can pass through
      # literal client IDs/secrets. Shell-backed schemes go through an injected
      # `runner` (Open3-compatible) so specs never spawn a process; env lookups
      # read an injected `env` hash so they never mutate the global ENV.
      #
      #   secret:env:VAR          -> env["VAR"]
      #   secret:dashlane:NAME    -> `dcli read NAME`
      #   secret:keychain:LABEL   -> `security find-generic-password -s ... -a LABEL -w`
      class ReadSecretRef
        extend Callable

        PREFIX = "secret:".freeze
        KEYCHAIN_SERVICE = "slack-status-cli".freeze

        def initialize(value:, runner: Open3, env: ENV)
          @value = value
          @runner = runner
          @env = env
        end

        def call
          return value if value.nil?
          return value unless value.to_s.start_with?(PREFIX)

          scheme, locator = value.to_s.delete_prefix(PREFIX).split(":", 2)
          case scheme
          when "env" then env[locator.to_s]
          when "dashlane" then shell_out("dcli", "read", locator.to_s)
          when "keychain" then shell_out("security", "find-generic-password", "-s", KEYCHAIN_SERVICE, "-a", locator.to_s, "-w")
          else
            raise Errors::UnknownSecretScheme, "unknown secret scheme '#{scheme}' in #{value}"
          end
        end

        private

        attr_reader :value, :runner, :env

        def shell_out(*argv)
          stdout, _stderr, status = runner.capture3(*argv)
          return nil unless status.success?

          stripped = stdout.to_s.strip
          stripped.empty? ? nil : stripped
        rescue ::Errno::ENOENT
          nil
        end
      end
    end
  end
end
