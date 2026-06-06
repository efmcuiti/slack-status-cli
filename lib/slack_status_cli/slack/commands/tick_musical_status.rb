module SlackStatusCli
  module Slack
    module Commands
      # Runs a single musical-myth tick: fetches the current track, derives its
      # playback state, sets the Slack status to the formatted now-playing text
      # (trimmed to Slack's 100-char limit) with the `:music:` emoji, and
      # returns the enriched tune (`{state:, name:, artist:, album:}`) so the
      # caller (RunMusicalLoop) can pick the next sleep cadence. When nothing is
      # playing the status update is skipped entirely. `current_track:` is
      # injectable so specs can drive it without shelling out.
      class TickMusicalStatus
        extend Callable

        STATUS_EMOJI = ":music:".freeze

        def initialize(token:, current_track: Music::Queries::CurrentTrack, output: $stdout)
          @token = token
          @current_track = current_track
          @output = output
        end

        def call
          tune = enriched_tune
          text = Formatters::StatusTextTrimmer.call(text: Formatters::TuneText.call(tune: tune))
          SetStatus.call(token: token, text: text, emoji: STATUS_EMOJI, expiration: nil, output: output) unless text.empty?
          tune
        end

        private

        attr_reader :token, :current_track, :output

        def enriched_tune
          raw = current_track.call
          {
            state: Music::Queries::TuneState.call(tune: raw),
            name: raw[:name],
            artist: raw[:artist],
            album: raw[:album]
          }
        end
      end
    end
  end
end
