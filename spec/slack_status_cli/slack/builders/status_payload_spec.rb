require "spec_helper"
require "json"

RSpec.describe SlackStatusCli::Slack::Builders::StatusPayload do
  describe ".call" do
    let(:now) { Time.at(1_700_000_000) }

    def profile(json)
      JSON.parse(json).fetch("profile")
    end

    it "returns a JSON string with the profile status keys" do
      json = described_class.call(text: "heads down", emoji: ":wolf:", expiration: nil)

      expect(profile(json)).to include(
        "status_text" => "heads down",
        "status_emoji" => ":wolf:"
      )
    end

    it "passes a nil expiration through as 0" do
      json = described_class.call(text: "", emoji: "", expiration: nil)

      expect(profile(json)["status_expiration"]).to eq(0)
    end

    it "expands a relative expiration via ExpirationSeconds" do
      json = described_class.call(text: "lunch", emoji: ":meat_on_bone:", expiration: "30m", now: now)

      expect(profile(json)["status_expiration"]).to eq(now.to_i + (30 * 60))
    end

    it "resolves a bare integer expiration as relative seconds-from-now" do
      json = described_class.call(text: "", emoji: "", expiration: "3600", now: now)

      expect(profile(json)["status_expiration"]).to eq(now.to_i + 3600)
    end
  end
end
