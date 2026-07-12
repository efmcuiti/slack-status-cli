require "spec_helper"
require "stringio"

RSpec.describe SlackStatusCli::Slack::Commands::RunMusicalLoop do
  describe ".call" do
    let(:token) { "xoxp-test-token-1234" }
    let(:output) { StringIO.new }

    # A fake `tick:` collaborator: records the token + output it was called
    # with and returns a fixed enriched tune so NextInterval can derive a
    # cadence. Requiring `output:` pins the contract that the loop threads its
    # output stream through to the tick.
    def recording_tick(tokens, outputs, tune:)
      ->(token:, output:) { tokens << token; outputs << output; tune }
    end

    it "ticks then sleeps for the NextInterval cadence" do
      tokens = []
      tick = recording_tick(tokens, [], tune: build_tune(state: :playing))
      sleeper = FakeSleeper.new(raise_after: 1)

      described_class.call(token: token, sleeper: sleeper, tick: tick, output: output)

      expect(tokens.size).to eq(1)
      expect(sleeper.calls).to eq([120])
    end

    it "stops cleanly when the sleeper raises StopIteration" do
      tokens = []
      tick = recording_tick(tokens, [], tune: build_tune(state: :playing))
      sleeper = FakeSleeper.new(raise_after: 2)

      expect do
        described_class.call(token: token, sleeper: sleeper, tick: tick, output: output)
      end.not_to raise_error

      expect(tokens.size).to eq(2)
    end

    it "passes the token through to the tick collaborator" do
      tokens = []
      tick = recording_tick(tokens, [], tune: build_tune(state: :playing))
      sleeper = FakeSleeper.new(raise_after: 1)

      described_class.call(token: token, sleeper: sleeper, tick: tick, output: output)

      expect(tokens).to eq([token])
    end

    it "threads its output stream through to the tick collaborator" do
      outputs = []
      tick = recording_tick([], outputs, tune: build_tune(state: :playing))
      sleeper = FakeSleeper.new(raise_after: 1)

      described_class.call(token: token, sleeper: sleeper, tick: tick, output: output)

      expect(outputs).to eq([output])
    end

    context "telemetry" do
      it "emits a debug tick event each cycle with state and interval" do
        tick = ->(token:, output:) { build_tune(state: :playing) }
        telemetry = CapturingTelemetry.new
        sleeper = FakeSleeper.new(raise_after: 1)

        described_class.call(token: token, sleeper: sleeper, tick: tick, output: output, telemetry: telemetry)

        entry = telemetry.entry_for("musical loop tick")
        expect(entry.level).to eq(:debug)
        expect(entry.tags).to include(state: "playing", interval: 120)
      end

      it "emits a track-changed event when the track changes" do
        tunes = [build_tune(name: "Aurora"), build_tune(name: "Lisztomania")]
        tick = ->(token:, output:) { tunes.shift }
        telemetry = CapturingTelemetry.new
        sleeper = FakeSleeper.new(raise_after: 2)

        described_class.call(token: token, sleeper: sleeper, tick: tick, output: output, telemetry: telemetry)

        changed = telemetry.entries.select { |entry| entry.message == "musical track changed" }
        expect(changed.map { |entry| entry.tags[:name] }).to eq(["Aurora", "Lisztomania"])
      end

      it "does not repeat a track-changed event while the same track keeps playing" do
        tick = ->(token:, output:) { build_tune(name: "Aurora") }
        telemetry = CapturingTelemetry.new
        sleeper = FakeSleeper.new(raise_after: 3)

        described_class.call(token: token, sleeper: sleeper, tick: tick, output: output, telemetry: telemetry)

        changed = telemetry.entries.select { |entry| entry.message == "musical track changed" }
        expect(changed.size).to eq(1)
      end

      it "does not re-announce the same track after an intervening errored tick" do
        sequence = [-> { build_tune(name: "Aurora") }, -> { raise "network blip" }, -> { build_tune(name: "Aurora") }]
        tick = ->(token:, output:) { sequence.shift.call }
        telemetry = CapturingTelemetry.new
        sleeper = FakeSleeper.new(raise_after: 3)

        described_class.call(token: token, sleeper: sleeper, tick: tick, output: output, telemetry: telemetry)

        changed = telemetry.entries.select { |entry| entry.message == "musical track changed" }
        expect(changed.size).to eq(1)
      end

      it "logs a warn tick-failed event with the error class and reason" do
        tick = ->(token:, output:) { raise "boom detonation" }
        telemetry = CapturingTelemetry.new
        sleeper = FakeSleeper.new(raise_after: 1)

        described_class.call(token: token, sleeper: sleeper, tick: tick, output: output, telemetry: telemetry)

        entry = telemetry.entry_for("musical tick failed")
        expect(entry.level).to eq(:warn)
        expect(entry.tags[:reason]).to include("boom detonation")
      end
    end
  end
end
