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

        def initialize(token:, sleeper: Kernel.method(:sleep), tick: TickMusicalStatus, output: $stdout)
          @token = token
          @sleeper = sleeper
          @tick = tick
          @output = output
        end

        def call
          loop do
            tune = safe_tick
            interval = Formatters::NextInterval.call(tune: tune)
            output.puts "😴 for #{interval} seconds... (#{Formatters::StateLabel.call(tune: tune)})"
            sleeper.call(interval)
          end
        end

        private

        attr_reader :token, :sleeper, :tick, :output

        def safe_tick
          tick.call(token: token, output: output)
        rescue StandardError => e
          output.puts "⚠️  Tick failed: #{e.class}: #{e.message} — will retry next cycle."
          nil
        end
      end
    end
  end
end
