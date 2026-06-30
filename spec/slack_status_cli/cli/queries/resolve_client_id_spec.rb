require "spec_helper"

RSpec.describe SlackStatusCli::Cli::Queries::ResolveClientId do
  describe ".call" do
    it "returns the profile-level client_id when configured" do
      config = build_config(
        global: { "oauth" => { "client_id" => "global.id" } },
        profiles: { "work" => { "oauth" => { "client_id" => "work.id" } } },
      )
      expect(described_class.call(config: config, profile: "work", env: {})).to eq("work.id")
    end

    it "falls back to the global client_id when the profile has none" do
      config = build_config(global: { "oauth" => { "client_id" => "global.id" } })
      expect(described_class.call(config: config, profile: "work", env: {})).to eq("global.id")
    end

    it "falls back to ENV (SLACK_STATUS_CLIENT_ID) when config is empty" do
      expect(described_class.call(config: build_config, profile: "work", env: { "SLACK_STATUS_CLIENT_ID" => "env.id" }))
        .to eq("env.id")
    end

    it "returns nil when nothing resolves" do
      expect(described_class.call(config: build_config, profile: "work", env: {})).to be_nil
    end

    it "expands a secret: ref via ReadSecretRef" do
      config = build_config(global: { "oauth" => { "client_id" => "secret:env:CID" } })
      expect(described_class.call(config: config, profile: "work", env: { "CID" => "expanded.id" }))
        .to eq("expanded.id")
    end
  end
end
