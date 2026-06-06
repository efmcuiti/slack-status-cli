require "spec_helper"

RSpec.describe SlackStatusCli::Slack::Builders::ModeStatus do
  describe ".call" do
    context "with :myth" do
      it "returns an empty text, a mythical emoji, and no expiration" do
        result = described_class.call(mode: :myth)

        expect(result[:text]).to eq("")
        expect(described_class::MYTH_MOJIS).to include(result[:emoji])
        expect(result[:expiration]).to be_nil
      end
    end

    context "with :musical_myth" do
      it "returns the music emoji, an empty text, and no expiration" do
        result = described_class.call(mode: :musical_myth)

        expect(result).to include(text: "", emoji: ":music:", expiration: nil)
      end
    end

    context "with :lunch" do
      it "returns the lunch emoji and a one-hour relative expiration offset" do
        result = described_class.call(mode: :lunch)

        expect(result[:emoji]).to eq(":meat_on_bone:")
        expect(result[:text]).to match(/Lunch time!/)
        expect(result[:expiration]).to eq(3600)
      end
    end

    context "with :break" do
      it "returns the coffee emoji and a thirty-minute relative expiration offset" do
        result = described_class.call(mode: :break)

        expect(result[:emoji]).to eq(":coffee:")
        expect(result[:text]).to match(/Taking a break/)
        expect(result[:expiration]).to eq(1800)
      end
    end

    context "with an unknown mode" do
      it "raises a clear ArgumentError naming the mode" do
        expect { described_class.call(mode: :nonsense) }
          .to raise_error(ArgumentError, /nonsense/)
      end
    end
  end
end
