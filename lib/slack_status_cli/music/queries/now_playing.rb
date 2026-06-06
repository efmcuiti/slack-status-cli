require "open3"
require "json"

module SlackStatusCli
  module Music
    module Queries
      # Fetches the current track from MediaRemote via `nowplaying-cli`, the
      # primary now-playing source. Returns a raw tune hash
      # (`{ name:, artist:, album:, playing: }`) or `Constants::NULL_TRACK`
      # when the command fails, the JSON is unparseable, or no title is set.
      # The shell collaborator is injected as `runner:` so specs can drive it
      # with a FakeShellRunner instead of spawning a process.
      class NowPlaying
        extend Callable

        COMMAND = ["nowplaying-cli", "get", "--json", "title", "artist", "album", "playbackRate"].freeze

        def initialize(runner: Open3)
          @runner = runner
        end

        def call
          stdout, _stderr, status = runner.capture3(*COMMAND)
          return null_track unless status.success?
        rescue Errno::ENOENT
          # `nowplaying-cli` is not installed / not on PATH. Degrade to a
          # silent tune instead of crashing the caller (the loop keeps
          # ticking; the AppleScript fallback may still find a track).
          null_track
        else
          payload = parse_json(stdout)
          return null_track if payload.nil?

          title = nullify(payload["title"])
          return null_track if title.nil?

          {
            name: title,
            artist: nullify(payload["artist"]),
            album: nullify(payload["album"]),
            playing: playback_rate_to_playing(payload["playbackRate"])
          }
        end

        private

        attr_reader :runner

        def parse_json(raw)
          JSON.parse(raw.to_s.strip)
        rescue JSON::ParserError
          nil
        end

        # An explicit playbackRate of 0 means paused; a missing/nil rate falls
        # back to "playing" to preserve prior behavior when MediaRemote omits
        # the field.
        def playback_rate_to_playing(rate)
          return false if rate.is_a?(Numeric) && rate <= 0
          return false if rate.is_a?(String) && rate.strip == "0"

          true
        end

        def nullify(value)
          return nil if value.nil?

          stripped = value.to_s.strip
          return nil if stripped.empty? || stripped == "null"

          stripped
        end

        def null_track
          Constants::NULL_TRACK.dup
        end
      end
    end
  end
end
