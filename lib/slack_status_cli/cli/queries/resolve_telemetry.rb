module SlackStatusCli
  module Cli
    module Queries
      # Composition-root switch for diagnostic telemetry. Reads SLACK_STATUS_LOG
      # and returns the no-op NullLogger (off by default) unless logging is
      # enabled ("json" or a level), in which case it builds a real
      # StructuredLogger writing to $stderr with a fresh per-invocation run_id.
      # StructuredLogger already routes through SecretScrubber, so the real path
      # scrubs secrets automatically. The off check is case/whitespace-insensitive.
      class ResolveTelemetry
        extend Callable

        ENV_VAR = "SLACK_STATUS_LOG".freeze
        OFF_VALUES = ["", "off"].freeze

        def initialize(env: ENV)
          @env = env
        end

        def call
          return Telemetry::NullLogger.new if disabled?

          Telemetry::StructuredLogger.new(io: $stderr, run_id: Telemetry::RunContext.generate)
        end

        private

        attr_reader :env

        def disabled?
          value = env[ENV_VAR]
          value.nil? || OFF_VALUES.include?(value.strip.downcase)
        end
      end
    end
  end
end
