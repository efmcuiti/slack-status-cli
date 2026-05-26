require "spec_helper"

RSpec.describe SlackStatusCli::Slack::Formatters::TuneText do
  describe ".call" do
    context "when tune state is :playing" do
      it "returns the playing format with myth emoji, track, artist, and album" do
        allow(described_class::MYTH_MOJIS).to receive(:sample).and_return(":wolf:")
        tune = build_tune(state: :playing, name: "Aurora", artist: "Phoenix", album: "Bankrupt!")

        result = described_class.call(tune: tune)

        expect(result).to eq("♪♬  :wolf: Aurora - Phoenix (Bankrupt!)")
      end
    end

    context "when tune state is :paused" do
      it "returns the paused format with myth emoji, paused phrase, track, and artist" do
        allow(described_class::MYTH_MOJIS).to receive(:sample).and_return(":fox_face:")
        allow(described_class::PAUSED_PHRASES).to receive(:sample).and_return("the oracle is thinking…")
        tune = build_tune(state: :paused, name: "Aurora", artist: "Phoenix")

        result = described_class.call(tune: tune)

        expect(result).to eq("⏸️ :fox_face: the oracle is thinking… — Aurora - Phoenix")
      end
    end

    context "when tune state is :silent" do
      it "returns an empty string so the caller can skip updating the status" do
        tune = build_tune(state: :silent, name: nil, artist: nil, album: nil)

        expect(described_class.call(tune: tune)).to eq("")
      end
    end

    it "draws each myth emoji from a non-empty constant of slack-style codes" do
      expect(described_class::MYTH_MOJIS).to all(match(/\A:[a-z_]+:\z/))
      expect(described_class::MYTH_MOJIS).not_to be_empty
    end

    it "draws each paused phrase from a non-empty constant of strings" do
      expect(described_class::PAUSED_PHRASES).to all(be_a(String))
      expect(described_class::PAUSED_PHRASES).not_to be_empty
    end
  end
end
