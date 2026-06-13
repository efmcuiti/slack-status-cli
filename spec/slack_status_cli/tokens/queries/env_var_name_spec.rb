require "spec_helper"

RSpec.describe SlackStatusCli::Tokens::Queries::EnvVarName do
  describe ".call" do
    it "returns SLACK_STATUS_TOKEN_DEFAULT for the default profile" do
      expect(described_class.call(profile: "default")).to eq("SLACK_STATUS_TOKEN_DEFAULT")
    end

    it "uppercases and sanitizes non-default profile names" do
      expect(described_class.call(profile: "work-account")).to eq("SLACK_STATUS_TOKEN_WORK_ACCOUNT")
    end

    it "replaces each non-alphanumeric character with its own underscore" do
      expect(described_class.call(profile: "my  work")).to eq("SLACK_STATUS_TOKEN_MY__WORK")
    end
  end
end
