require "spec_helper"

RSpec.describe SlackStatusCli::Slack::Formatters::NextInterval do
  describe ".call" do
    it "returns 120 seconds (a full cycle) when tune state is :playing" do
      result = described_class.call(tune: build_tune(state: :playing))

      expect(result).to eq(120)
    end

    it "returns 30 seconds (a quick check-in) when tune state is :paused" do
      result = described_class.call(tune: build_tune(state: :paused))

      expect(result).to eq(30)
    end

    it "returns 120 seconds (a long nap) when tune state is :silent" do
      result = described_class.call(tune: build_tune(state: :silent, name: nil, artist: nil, album: nil))

      expect(result).to eq(120)
    end

    it "falls back to the playing cadence when tune is nil (tick errored out)" do
      expect(described_class.call(tune: nil)).to eq(120)
    end

    it "falls back to the playing cadence when tune has no :state key" do
      expect(described_class.call(tune: { name: "Aurora" })).to eq(120)
    end
  end
end
