module SlackStatusCli
  module Slack
    module Formatters
      # Builds the Slack status text for a now-playing tune. Reads
      # `tune[:state]` (`:playing`, `:paused`, or `:silent`) and returns the
      # matching format. Silent state returns "" so the caller can skip the
      # update entirely. Trimming to Slack's 100-char limit is the caller's
      # job (compose with `StatusTextTrimmer`).
      class TuneText
        extend Callable

        MYTH_MOJIS = [":wolf:", ":lion_face:", ":phoenix_ash:", ":fox_face:", ":butterfly:"]

        PAUSED_PHRASES = [
          "intermission — the muse catches their breath",
          "the oracle is thinking…",
          "holding the lyre still",
          "mid-myth pause (not the final chapter)",
          "feral focus: recharge mode",
          "silence before the chorus",
          "the siren is on break",
          "embers cooling — not extinct"
        ]

        def initialize(tune:)
          @tune = tune
        end

        def call
          case tune[:state]
          when :silent then ""
          when :paused then paused_status
          else playing_status
          end
        end

        private

        attr_reader :tune

        def playing_status
          "♪♬  #{MYTH_MOJIS.sample} #{tune[:name]} - #{tune[:artist]} (#{tune[:album]})"
        end

        def paused_status
          "⏸️ #{MYTH_MOJIS.sample} #{PAUSED_PHRASES.sample} — #{tune[:name]} - #{tune[:artist]}"
        end
      end
    end
  end
end
