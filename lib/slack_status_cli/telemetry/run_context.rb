require "securerandom"

module SlackStatusCli
  module Telemetry
    # Mints the per-invocation correlation id (run_id) the composition root
    # (T9.3) hands to StructuredLogger, so every line emitted during one CLI
    # run — including concurrent work — shares a single id. A stateless
    # generator, so it exposes a bare `.generate` rather than the Callable
    # `.call` used by input-taking queries/commands.
    class RunContext
      DEFAULT_BYTES = 8

      def self.generate(bytes: DEFAULT_BYTES)
        ::SecureRandom.hex(bytes)
      end
    end
  end
end
