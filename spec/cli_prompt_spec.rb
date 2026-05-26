require "spec_helper"
require "cli_prompt"

RSpec.describe CliPrompt do
  describe ".scrub_secrets" do
    it "redacts an xoxp-* token to the same xox?-…LAST4 shape SecretScrubber uses" do
      result = described_class.scrub_secrets("token=xoxp-abcd1234efgh tail")

      expect(result).to eq("token=xox?-…efgh tail")
    end

    it "redacts an xoxb-* token" do
      expect(described_class.scrub_secrets("bot=xoxb-0987zyxw")).to eq("bot=xox?-…zyxw")
    end

    it "redacts every match when multiple tokens appear in the same string" do
      result = described_class.scrub_secrets("a=xoxp-firsttok1111 b=xoxb-secondtok2222")

      expect(result).to eq("a=xox?-…1111 b=xox?-…2222")
    end

    it "leaves non-token text unchanged" do
      expect(described_class.scrub_secrets("nothing sensitive, xox in prose stays put"))
        .to eq("nothing sensitive, xox in prose stays put")
    end

    it "returns nil when given nil" do
      expect(described_class.scrub_secrets(nil)).to be_nil
    end

    it "is idempotent: scrubbing scrubbed text is a no-op" do
      once = described_class.scrub_secrets("token=xoxp-abcd1234efgh tail")
      twice = described_class.scrub_secrets(once)

      expect(twice).to eq(once)
    end
  end
end
