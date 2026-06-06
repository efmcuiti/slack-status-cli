require "spec_helper"
require "stringio"

RSpec.describe SlackStatusCli::Slack::Commands::RunMusicalLoop do
  describe ".call" do
    let(:token) { "xoxp-test-token-1234" }
    let(:output) { StringIO.new }

    # A fake `tick:` collaborator: records the token it was called with and
    # returns a fixed enriched tune so NextInterval can derive a cadence.
    def recording_tick(store, tune:)
      ->(token:) { store << token; tune }
    end

    it "ticks then sleeps for the NextInterval cadence" do
      tokens = []
      tick = recording_tick(tokens, tune: build_tune(state: :playing))
      sleeper = FakeSleeper.new(raise_after: 1)

      described_class.call(token: token, sleeper: sleeper, tick: tick, output: output)

      expect(tokens.size).to eq(1)
      expect(sleeper.calls).to eq([120])
    end

    it "stops cleanly when the sleeper raises StopIteration" do
      tokens = []
      tick = recording_tick(tokens, tune: build_tune(state: :playing))
      sleeper = FakeSleeper.new(raise_after: 2)

      expect do
        described_class.call(token: token, sleeper: sleeper, tick: tick, output: output)
      end.not_to raise_error

      expect(tokens.size).to eq(2)
    end

    it "passes the token through to the tick collaborator" do
      tokens = []
      tick = recording_tick(tokens, tune: build_tune(state: :playing))
      sleeper = FakeSleeper.new(raise_after: 1)

      described_class.call(token: token, sleeper: sleeper, tick: tick, output: output)

      expect(tokens).to eq([token])
    end
  end
end
