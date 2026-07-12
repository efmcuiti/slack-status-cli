module SlackStatusCli
  module Slack
    module Commands
      # The musical-myth loop: ticks the status, logs the chosen cadence, then
      # sleeps for `NextInterval` seconds — forever. A failed tick is rescued to
      # `nil` (the loop keeps the conservative playing cadence and retries next
      # cycle) so a transient music/Slack hiccup never tears the loop down.
      # `sleeper:` and `tick:` are injectable: specs pass a FakeSleeper that
      # raises StopIteration to run the real loop body a finite number of times.
      class RunMusicalLoop
        extend Callable

        def initialize(token:, sleeper: Kernel.method(:sleep), tick: TickMusicalStatus, output: $stdout, telemetry: Telemetry::NullLogger.new)
          @token = token
          @sleeper = sleeper
          @tick = tick
          @output = output
          @telemetry = telemetry
        end

        def call
          last_track = nil
          loop do
            tune = safe_tick
            interval = Formatters::NextInterval.call(tune: tune)
            label = Formatters::StateLabel.call(tune: tune)
            output.puts "😴 for #{interval} seconds... (#{label})"

            telemetry.rich_log(message: "musical loop tick", level: :debug, tags: { state: label, interval: interval })
            track = track_key(tune)
            if track && track != last_track
              telemetry.rich_log(message: "musical track changed", tags: { name: tune[:name], artist: tune[:artist] })
            end
            last_track = track

            sleeper.call(interval)
          end
        end

        private

        attr_reader :token, :sleeper, :tick, :output, :telemetry

        # A stable identity for the currently playing track, or nil when there is
        # no named track (silent/errored ticks), so track-change stays quiet then.
        def track_key(tune)
          return nil unless tune.is_a?(Hash) && tune[:name]

          [tune[:name], tune[:artist]]
        end

        def safe_tick
          tick.call(token: token, output: output)
        rescue StandardError => e
          output.puts "⚠️  Tick failed: #{e.class}: #{e.message} — will retry next cycle."
          telemetry.rich_log(message: "musical tick failed", level: :warn, tags: { error: e.class.name, reason: e.message })
          nil
        end
      end
    end
  end
end
