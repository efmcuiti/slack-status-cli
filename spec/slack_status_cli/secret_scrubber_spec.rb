require "spec_helper"

RSpec.describe SlackStatusCli::SecretScrubber do
  describe ".call" do
    it "redacts an xoxp-* user token, keeping only the last 4 characters" do
      result = described_class.call(text: "token=xoxp-abcd1234efgh and the rest")

      expect(result).to eq("token=xox?-…efgh and the rest")
    end

    it "redacts an xoxb-* bot token" do
      result = described_class.call(text: "bot=xoxb-0987zyxw")

      expect(result).to eq("bot=xox?-…zyxw")
    end

    it "redacts an xoxa-* app token" do
      result = described_class.call(text: "app xoxa-2222aaaa3333 leak")

      expect(result).to eq("app xox?-…3333 leak")
    end

    it "redacts every match when multiple tokens appear in the same string" do
      result = described_class.call(text: "a=xoxp-firsttok1111 b=xoxb-secondtok2222")

      expect(result).to eq("a=xox?-…1111 b=xox?-…2222")
    end

    it "leaves non-token text unchanged" do
      result = described_class.call(text: "nothing sensitive here, xox in prose stays put")

      expect(result).to eq("nothing sensitive here, xox in prose stays put")
    end

    it "returns nil when given nil so callers can scrub optional fields safely" do
      expect(described_class.call(text: nil)).to be_nil
    end

    it "is idempotent: scrubbing already-scrubbed text is a no-op" do
      once = described_class.call(text: "token=xoxp-abcd1234efgh tail")
      twice = described_class.call(text: once)

      expect(twice).to eq(once)
    end
  end
end
