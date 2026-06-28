require "spec_helper"

RSpec.describe SlackStatusCli::EmojiMigration::Queries::FilteredEntries do
  describe ".call" do
    it "separates 'alias:foo' entries into aliases vs real urls" do
      emoji_map = build_emoji_map(
        real: { "phoenix_ash" => "https://emoji.slack-edge.com/T1/phoenix_ash/abc.png" },
        aliases: { "phoenix_alias" => "phoenix_ash" }
      )

      result = described_class.call(emoji_map: emoji_map)

      expect(result[:real]).to eq("phoenix_ash" => "https://emoji.slack-edge.com/T1/phoenix_ash/abc.png")
      expect(result[:aliases]).to eq("phoenix_alias" => "phoenix_ash")
      expect(result[:skipped]).to eq([])
    end

    it "passes through all entries when pattern is nil" do
      emoji_map = build_emoji_map(
        real: {
          "alpha" => "https://emoji.slack-edge.com/T1/alpha/a.png",
          "beta" => "https://emoji.slack-edge.com/T1/beta/b.png"
        }
      )

      result = described_class.call(emoji_map: emoji_map, pattern: nil)

      expect(result[:real].keys).to contain_exactly("alpha", "beta")
    end

    it "filters by regex pattern when given" do
      emoji_map = build_emoji_map(
        real: {
          "phoenix_ash" => "https://emoji.slack-edge.com/T1/phoenix_ash/a.png",
          "rocket" => "https://emoji.slack-edge.com/T1/rocket/r.png"
        }
      )

      result = described_class.call(emoji_map: emoji_map, pattern: "phoenix")

      expect(result[:real].keys).to eq(["phoenix_ash"])
    end

    it "matches the pattern case-insensitively" do
      emoji_map = build_emoji_map(
        real: { "Phoenix_Ash" => "https://emoji.slack-edge.com/T1/Phoenix_Ash/a.png" }
      )

      result = described_class.call(emoji_map: emoji_map, pattern: "phoenix")

      expect(result[:real].keys).to eq(["Phoenix_Ash"])
    end

    it "returns skipped names for unparseable entries" do
      emoji_map = {
        "good" => "https://emoji.slack-edge.com/T1/good/g.png",
        "broken" => nil,
        "empty" => "",
        "weird" => "ftp://nope"
      }

      result = described_class.call(emoji_map: emoji_map)

      expect(result[:real].keys).to eq(["good"])
      expect(result[:skipped]).to contain_exactly("broken", "empty", "weird")
    end

    it "treats a nil emoji_map as empty" do
      result = described_class.call(emoji_map: nil)

      expect(result).to eq(real: {}, aliases: {}, skipped: [])
    end
  end
end
