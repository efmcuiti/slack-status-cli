require "spec_helper"

RSpec.describe SlackStatusCli::Slack::Builders::ModeStatus do
  describe ".call" do
    let(:now) { Time.at(1_700_000_000) }

    context "with :myth" do
      it "returns an empty text, a mythical emoji, and no expiration" do
        result = described_class.call(mode: :myth, now: now)

        expect(result[:text]).to eq("")
        expect(described_class::MYTH_MOJIS).to include(result[:emoji])
        expect(result[:expiration]).to be_nil
      end
    end

    context "with :musical_myth" do
      it "returns the music emoji, an empty text, and no expiration" do
        result = described_class.call(mode: :musical_myth, now: now)

        expect(result).to include(text: "", emoji: ":music:", expiration: nil)
      end
    end

    context "with :lunch" do
      it "returns the lunch emoji and an expiration one hour from now:" do
        result = described_class.call(mode: :lunch, now: now)

        expect(result[:emoji]).to eq(":meat_on_bone:")
        expect(result[:text]).to match(/Lunch time!/)
        expect(result[:expiration]).to eq(now.to_i + 3600)
      end
    end

    context "with :break" do
      it "returns the coffee emoji and an expiration thirty minutes from now:" do
        result = described_class.call(mode: :break, now: now)

        expect(result[:emoji]).to eq(":coffee:")
        expect(result[:text]).to match(/Taking a break/)
        expect(result[:expiration]).to eq(now.to_i + 1800)
      end
    end

    context "with an unknown mode" do
      it "raises a clear ArgumentError naming the mode" do
        expect { described_class.call(mode: :nonsense, now: now) }
          .to raise_error(ArgumentError, /nonsense/)
      end
    end

    it "uses the injected now: when computing time-bound expirations" do
      later = Time.at(1_800_000_000)

      expect(described_class.call(mode: :lunch, now: later)[:expiration]).to eq(later.to_i + 3600)
    end
  end
end
