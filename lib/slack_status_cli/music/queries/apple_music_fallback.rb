require "open3"

module SlackStatusCli
  module Music
    module Queries
      # Secondary now-playing source: drives the Music.app AppleScript
      # (`Constants::SAFE_MUSIC_SCRIPT`) via `osascript` and parses its
      # `state|name|artist|album` pipe output into a raw tune hash. Returns
      # `Constants::NULL_TRACK` on shell failure or when nothing is playing.
      # The shell collaborator is injected as `runner:` for spec ergonomics.
      class AppleMusicFallback
        extend Callable

        def initialize(runner: Open3)
          @runner = runner
        end

        def call
          stdout, _stderr, status = runner.capture3("osascript", "-e", Constants::SAFE_MUSIC_SCRIPT)
          return null_track unless status.success?

          state, name, artist, album = stdout.strip.split("|").map { |part| nullify(part) }
          return null_track if name.nil?

          { name: name, artist: artist, album: album, playing: state == "playing" }
        end

        private

        attr_reader :runner

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
