require "spec_helper"

RSpec.describe SlackStatusCli::EmojiMigration::Queries::HumanBytes do
  describe ".call" do
    it "returns '0 B' for zero" do
      expect(described_class.call(bytes: 0)).to eq("0 B")
    end

    it "returns whole bytes below 1 KiB" do
      expect(described_class.call(bytes: 512)).to eq("512 B")
    end

    it "returns one-decimal KB between 1 KiB and 1 MiB" do
      expect(described_class.call(bytes: 1536)).to eq("1.5 KB")
    end

    it "returns one-decimal MB between 1 MiB and 1 GiB" do
      expect(described_class.call(bytes: 1024 * 1024 * 3 / 2)).to eq("1.5 MB")
    end

    it "returns one-decimal GB at or above 1 GiB" do
      expect(described_class.call(bytes: 1024 * 1024 * 1024 * 3 / 2)).to eq("1.5 GB")
    end
  end
end
