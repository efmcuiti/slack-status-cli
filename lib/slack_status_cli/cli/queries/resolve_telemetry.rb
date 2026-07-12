module SlackStatusCli
  module Cli
    module Queries
      # Composition-root switch for diagnostic telemetry. Reads SLACK_STATUS_LOG
      # and, off by default, returns the no-op NullLogger unless the value is a
      # recognized enabler ("json" or a log level) — any other value, including
      # a typo like "josn", stays off. When enabled it builds a real
      # StructuredLogger writing to $stderr with a fresh per-invocation run_id.
      # StructuredLogger already routes through SecretScrubber, so the real path
      # scrubs secrets automatically. Matching is case/whitespace-insensitive.
      class ResolveTelemetry
        extend Callable

        ENV_VAR = "SLACK_STATUS_LOG".freeze
        ENABLED_VALUES = (["json"] + Telemetry::StructuredLogger::VALID_LEVELS.map(&:to_s)).freeze

        def initialize(env: ENV)
          @env = env
        end

        def call
          return Telemetry::NullLogger.new unless enabled?

          Telemetry::StructuredLogger.new(io: $stderr, run_id: Telemetry::RunContext.generate)
        end

        private

        attr_reader :env

        def enabled?
          ENABLED_VALUES.include?(env[ENV_VAR].to_s.strip.downcase)
        end
      end
    end
  end
end
