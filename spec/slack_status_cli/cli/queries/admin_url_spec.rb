require "spec_helper"

RSpec.describe SlackStatusCli::Cli::Queries::AdminUrl do
  describe ".call" do
    it "returns the customize/emoji admin URL for the workspace" do
      expect(described_class.call(workspace_url: "https://phoenix-hq.slack.com"))
        .to eq("https://phoenix-hq.slack.com/customize/emoji")
    end

    it "strips trailing slashes before appending the admin path" do
      expect(described_class.call(workspace_url: "https://phoenix-hq.slack.com/"))
        .to eq("https://phoenix-hq.slack.com/customize/emoji")
    end

    it "returns nil for a blank workspace URL" do
      expect(described_class.call(workspace_url: "")).to be_nil
      expect(described_class.call(workspace_url: nil)).to be_nil
    end
  end
end
