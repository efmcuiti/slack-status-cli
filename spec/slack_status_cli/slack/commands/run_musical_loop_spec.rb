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
  end
end
