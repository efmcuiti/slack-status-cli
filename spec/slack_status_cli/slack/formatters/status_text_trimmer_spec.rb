require "spec_helper"

RSpec.describe SlackStatusCli::Slack::Formatters::StatusTextTrimmer do
  describe ".call" do
    it "returns text unchanged when shorter than max_len" do
      result = described_class.call(text: "short and sweet", max_len: 100)

      expect(result).to eq("short and sweet")
    end

    it "returns text unchanged when exactly at max_len" do
      text = "x" * 100

      expect(described_class.call(text: text, max_len: 100)).to eq(text)
    end

    it "returns blank text unchanged so empty status messages stay empty" do
      expect(described_class.call(text: "")).to eq("")
      expect(described_class.call(text: "   ")).to eq("   ")
    end

    it "normalizes nil input to an empty string so callers always get a String" do
      result = described_class.call(text: nil)

      expect(result).to eq("")
      expect(result).to be_a(String)
    end

    it "truncates with the default ellipsis when longer than max_len" do
      result = described_class.call(text: "alpha beta gamma delta", max_len: 12)

      expect(result).to eq("alpha beta…")
    end

    it "respects a custom ellipsis" do
      result = described_class.call(text: "alpha beta gamma delta", max_len: 14, ellipsis: "...")

      expect(result).to eq("alpha beta...")
    end

    it "falls back to a hard cut when no whitespace exists inside the slice" do
      result = described_class.call(text: "supercalifragilisticexpialidocious", max_len: 10)

      expect(result).to eq("supercali…")
    end

    it "counts grapheme clusters so emoji do not get sliced mid-sequence" do
      text = "🐺🦁🔥🦊🦋 myth herd on the move"
      result = described_class.call(text: text, max_len: 7)

      expect(result.grapheme_clusters.length).to be <= 7
      expect(result).to end_with("…")
      expect(result.grapheme_clusters.first(5)).to eq(%w[🐺 🦁 🔥 🦊 🦋])
    end
  end
end
