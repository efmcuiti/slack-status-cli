require "spec_helper"

RSpec.describe SlackStatusCli::Tokens::Queries::ProfileExplicitlyConfigured do
  describe ".call" do
    it "returns true when the profile has a non-empty block under profiles" do
      config = build_config(profiles: { "work" => { "storage_backend" => "keychain" } })

      expect(described_class.call(config: config, profile: "work")).to be(true)
    end

    it "returns false when the profile key is missing" do
      config = build_config(profiles: { "other" => { "storage_backend" => "file" } })

      expect(described_class.call(config: config, profile: "work")).to be(false)
    end

    it "returns false when the config is empty" do
      expect(described_class.call(config: {}, profile: "work")).to be(false)
    end

    it "returns false when the profile block is present but empty" do
      config = build_config(profiles: { "work" => {} })

      expect(described_class.call(config: config, profile: "work")).to be(false)
    end
  end
end
