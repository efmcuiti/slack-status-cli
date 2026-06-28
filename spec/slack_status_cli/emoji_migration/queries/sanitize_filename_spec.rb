require "spec_helper"

RSpec.describe SlackStatusCli::EmojiMigration::Queries::SanitizeFilename do
  describe ".call" do
    it "leaves alphanumeric, dashes, underscores, and pluses unchanged" do
      expect(described_class.call(name: "phoenix_ash-2+")).to eq("phoenix_ash-2+")
    end

    it "replaces unsafe characters with underscores" do
      expect(described_class.call(name: "weird/name:with*chars")).to eq("weird_name_with_chars")
    end

    it "replaces surrounding whitespace with underscores" do
      expect(described_class.call(name: " spaced ")).to eq("_spaced_")
    end

    it "coerces non-string input via to_s" do
      expect(described_class.call(name: :symbolic)).to eq("symbolic")
    end
  end
end
