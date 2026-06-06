require "open3"

module SlackStatusCli
  module Music
    module Queries
      # Orchestrates the now-playing sources: tries `NowPlaying` first and
      # returns its tune whenever it is non-null (a track with a name —
      # playing or paused), otherwise falls back to `AppleMusicFallback`.
      # Returns `Constants::NULL_TRACK` when both sources come up empty. The
      # shared `runner:` is threaded through to both queries so a single
      # FakeShellRunner can stub the whole chain.
      class CurrentTrack
        extend Callable

        def initialize(runner: Open3)
          @runner = runner
        end

        def call
          tune = NowPlaying.call(runner: runner)
          return tune unless tune[:name].nil?

          AppleMusicFallback.call(runner: runner)
        end

        private

        attr_reader :runner
      end
    end
  end
end
