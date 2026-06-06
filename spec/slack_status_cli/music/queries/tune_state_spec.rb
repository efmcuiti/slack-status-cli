require "spec_helper"

RSpec.describe SlackStatusCli::Music::Queries::TuneState do
  describe ".call" do
    it "returns :playing when a named tune is actively playing" do
      tune = { name: "Sirens", artist: "Cult of Luna", album: "Vertikal", playing: true }

      expect(described_class.call(tune: tune)).to eq(:playing)
    end

    it "returns :paused when a named tune is not playing" do
      tune = { name: "Sirens", artist: "Cult of Luna", album: "Vertikal", playing: false }

      expect(described_class.call(tune: tune)).to eq(:paused)
    end

    it "returns :silent when the tune is NULL_TRACK" do
      expect(described_class.call(tune: SlackStatusCli::Music::Constants::NULL_TRACK)).to eq(:silent)
    end

    it "defaults to :playing when the tune is nil (errored tick)" do
      expect(described_class.call(tune: nil)).to eq(:playing)
    end
  end
end
