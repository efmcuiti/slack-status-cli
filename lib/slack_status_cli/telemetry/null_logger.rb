module SlackStatusCli
  module Telemetry
    # The off switch: shares the StructuredLogger surface but no-ops rich_log.
    # It is the safe default for any optional `telemetry:` argument, so a pod
    # stays silent until the composition root injects a real logger.
    class NullLogger < StructuredLogger
      def rich_log(message:, tags: {}, level: :info)
        nil
      end
    end
  end
end
