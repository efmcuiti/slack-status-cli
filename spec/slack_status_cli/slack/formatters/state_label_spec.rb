require "spec_helper"

RSpec.describe SlackStatusCli::Slack::Formatters::StateLabel do
  describe ".call" do
    it "returns 'playing' when tune state is :playing" do
      result = described_class.call(tune: build_tune(state: :playing))

      expect(result).to eq("playing")
    end

    it "returns 'paused' when tune state is :paused" do
      result = described_class.call(tune: build_tune(state: :paused))

      expect(result).to eq("paused")
    end

    it "returns 'silent' when tune state is :silent" do
      result = described_class.call(tune: build_tune(state: :silent, name: nil, artist: nil, album: nil))

      expect(result).to eq("silent")
    end

    it "falls back to 'playing' when tune is nil so log lines stay tidy on errored ticks" do
      expect(described_class.call(tune: nil)).to eq("playing")
    end

    it "falls back to 'playing' when tune has no :state key" do
      expect(described_class.call(tune: { name: "Aurora" })).to eq("playing")
    end
  end
end
