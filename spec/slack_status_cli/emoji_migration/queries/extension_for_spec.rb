require "spec_helper"

RSpec.describe SlackStatusCli::EmojiMigration::Queries::ExtensionFor do
  describe ".call" do
    it "uses a recognized URL suffix when present" do
      ext = described_class.call(url: "https://emoji.slack-edge.com/T1/x/abc.gif", body: "ignored")

      expect(ext).to eq("gif")
    end

    it "normalizes the URL suffix to lowercase" do
      ext = described_class.call(url: "https://emoji.slack-edge.com/T1/x/abc.PNG", body: "ignored")

      expect(ext).to eq("png")
    end

    it "sniffs PNG magic bytes when the URL has no recognized suffix" do
      ext = described_class.call(url: "https://emoji.slack-edge.com/T1/x/blob", body: "\x89PNG\r\n\x1a\n")

      expect(ext).to eq("png")
    end

    it "sniffs GIF magic bytes when the URL has no recognized suffix" do
      ext = described_class.call(url: "https://emoji.slack-edge.com/T1/x/blob", body: "GIF89a...")

      expect(ext).to eq("gif")
    end

    it "sniffs JPEG magic bytes when the URL has no recognized suffix" do
      ext = described_class.call(url: "https://emoji.slack-edge.com/T1/x/blob", body: "\xFF\xD8\xFF\xE0")

      expect(ext).to eq("jpg")
    end

    it "falls back to 'bin' when neither the URL nor the magic bytes match" do
      ext = described_class.call(url: "https://emoji.slack-edge.com/T1/x/blob", body: "not-an-image")

      expect(ext).to eq("bin")
    end
  end
end
