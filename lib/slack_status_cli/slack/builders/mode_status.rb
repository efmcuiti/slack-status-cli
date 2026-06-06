module SlackStatusCli
  module Slack
    module Builders
      # Maps a mode symbol to the status triple Slack expects: text, emoji, and
      # an optional expiration. Time-bound modes (lunch/break) return a relative
      # seconds-from-now offset; Builders::ExpirationSeconds resolves it to an
      # absolute epoch at send time. Unknown modes raise rather than silently
      # returning nil.
      class ModeStatus
        extend Callable

        MYTH_MOJIS = [":wolf:", ":lion_face:", ":phoenix_ash:", ":fox_face:", ":butterfly:"].freeze
        LUNCH_SECONDS = 3600
        BREAK_SECONDS = 1800

        def initialize(mode:)
          @mode = mode
        end

        def call
          case mode
          when :myth
            { text: "", emoji: MYTH_MOJIS.sample, expiration: nil }
          when :musical_myth
            { text: "", emoji: ":music:", expiration: nil }
          when :lunch
            { text: "#{MYTH_MOJIS.sample} - Lunch time!", emoji: ":meat_on_bone:", expiration: LUNCH_SECONDS }
          when :break
            { text: "#{MYTH_MOJIS.sample} Taking a break", emoji: ":coffee:", expiration: BREAK_SECONDS }
          else
            raise ArgumentError, "Unknown mode: #{mode.inspect}"
          end
        end

        private

        attr_reader :mode
      end
    end
  end
end
