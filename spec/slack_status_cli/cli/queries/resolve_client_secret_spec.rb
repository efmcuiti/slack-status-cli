require "spec_helper"

RSpec.describe SlackStatusCli::Cli::Queries::ResolveClientSecret do
  describe ".call" do
    it "returns the profile-level client_secret_ref, expanded" do
      config = build_config(
        global: { "oauth" => { "client_secret_ref" => "secret:env:GLOBAL_CS" } },
        profiles: { "work" => { "oauth" => { "client_secret_ref" => "secret:env:WORK_CS" } } },
      )
      expect(described_class.call(config: config, profile: "work", env: { "WORK_CS" => "work-secret", "GLOBAL_CS" => "global-secret" }))
        .to eq("work-secret")
    end

    it "falls back to the global client_secret_ref" do
      config = build_config(global: { "oauth" => { "client_secret_ref" => "secret:env:GLOBAL_CS" } })
      expect(described_class.call(config: config, profile: "work", env: { "GLOBAL_CS" => "global-secret" }))
        .to eq("global-secret")
    end

    it "falls back to ENV (SLACK_STATUS_CLIENT_SECRET) when config is empty" do
      expect(described_class.call(config: build_config, profile: "work", env: { "SLACK_STATUS_CLIENT_SECRET" => "env-secret" }))
        .to eq("env-secret")
    end

    it "returns nil when nothing resolves" do
      expect(described_class.call(config: build_config, profile: "work", env: {})).to be_nil
    end
  end
end
