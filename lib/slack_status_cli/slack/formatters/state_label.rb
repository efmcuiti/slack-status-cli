module SlackStatusCli
  module Slack
    module Formatters
      # Returns a short, log-friendly label for the current tune state:
      # "playing", "paused", or "silent". Reads `tune[:state]`. Unknown
      # or missing state falls back to "playing" so errored ticks still
      # produce a sensible log line.
      class StateLabel
        extend Callable

        def initialize(tune:)
          @tune = tune
        end

        def call
          case state
          when :paused then "paused"
          when :silent then "silent"
          else "playing"
          end
        end

        private

        attr_reader :tune

        def state
          tune.is_a?(Hash) ? tune[:state] : nil
        end
      end
    end
  end
end
