module SlackStatusCli
  module Slack
    module Formatters
      # Returns the number of seconds the musical-myth loop should sleep
      # before the next tick. Reads `tune[:state]`. Unknown/missing state
      # defaults to the conservative playing cadence so transient
      # nowplaying-cli failures do not hammer Slack.
      class NextInterval
        extend Callable

        PLAYING_SLEEP = 120
        PAUSED_SLEEP = 30
        SILENT_SLEEP = 120

        def initialize(tune:)
          @tune = tune
        end

        def call
          case state
          when :paused then PAUSED_SLEEP
          when :silent then SILENT_SLEEP
          else PLAYING_SLEEP
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
