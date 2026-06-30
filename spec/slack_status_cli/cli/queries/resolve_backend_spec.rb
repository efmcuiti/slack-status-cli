require "spec_helper"

RSpec.describe SlackStatusCli::Cli::Queries::ResolveBackend do
  describe ".call" do
    it "returns :file by default when nothing is configured" do
      expect(described_class.call(config: build_config, profile: "work", env: {})).to eq(:file)
    end

    it "returns the profile-level storage_backend as a Symbol" do
      config = build_config(profiles: { "work" => { "storage_backend" => "keychain" } })
      expect(described_class.call(config: config, profile: "work", env: {})).to eq(:keychain)
    end

    it "falls back to the global storage_backend" do
      config = build_config(global: { "storage_backend" => "dashlane" })
      expect(described_class.call(config: config, profile: "work", env: {})).to eq(:dashlane)
    end

    it "reads SLACK_STATUS_BACKEND from ENV when no config value is present" do
      expect(described_class.call(config: build_config, profile: "work", env: { "SLACK_STATUS_BACKEND" => "env" }))
        .to eq(:env)
    end

    it "prefers a config value over the ENV override" do
      config = build_config(profiles: { "work" => { "storage_backend" => "keychain" } })
      expect(described_class.call(config: config, profile: "work", env: { "SLACK_STATUS_BACKEND" => "env" }))
        .to eq(:keychain)
    end

    it "strips surrounding whitespace before symbolizing" do
      config = build_config(profiles: { "work" => { "storage_backend" => " keychain " } })
      expect(described_class.call(config: config, profile: "work", env: {})).to eq(:keychain)
    end
  end
end
