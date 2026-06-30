require "spec_helper"

RSpec.describe SlackStatusCli::Cli::Queries::RedactedToken do
  describe ".call" do
    it "keeps the first `keep:` chars and masks the rest" do
      expect(described_class.call(token: "xoxp123", keep: 4)).to eq("xoxp***")
    end

    it "defaults to keeping the first 4 chars" do
      expect(described_class.call(token: "xoxpABCD")).to eq("xoxp****")
    end

    it "returns '' for a nil token" do
      expect(described_class.call(token: nil)).to eq("")
    end

    it "returns '<redacted>' for a token shorter than keep:" do
      expect(described_class.call(token: "ab", keep: 4)).to eq("<redacted>")
    end

    it "returns '<redacted>' when keep equals the token length (never fully unmasked)" do
      expect(described_class.call(token: "xoxp", keep: 4)).to eq("<redacted>")
    end

    it "fully masks without raising when keep is nil" do
      expect(described_class.call(token: "xoxp123", keep: nil)).to eq("*******")
    end

    it "clamps a negative keep to zero" do
      expect(described_class.call(token: "xoxp", keep: -3)).to eq("****")
    end
  end
end
