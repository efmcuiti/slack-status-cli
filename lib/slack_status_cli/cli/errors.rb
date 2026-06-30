module SlackStatusCli
  module Cli
    # CLI pod error vocabulary. The Cli pod owns its own failure types,
    # mirroring the Tokens and Oauth pods.
    module Errors
      class Error < StandardError; end

      # Raised when the user passes -h/--help. Carries the rendered help text so
      # the dispatcher can print it and exit, keeping the parser callable free of
      # I/O and process control.
      class HelpRequested < Error
        def initialize(help_text)
          @help_text = help_text
          super("help requested")
        end

        attr_reader :help_text
      end

      # Raised when a `secret:` reference names a backend scheme we don't know
      # how to resolve (anything other than env / dashlane / keychain).
      class UnknownSecretScheme < Error; end

      # Raised by `config get` when the requested dotted key resolves to nil.
      # The dispatcher maps this to a non-zero exit so scripts can branch on a
      # missing setting, mirroring the old inline `exit 1`.
      class ConfigKeyUnset < Error; end
    end
  end
end
