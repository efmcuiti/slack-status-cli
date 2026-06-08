require "spec_helper"

RSpec.describe SlackStatusCli::Tokens::Queries::MergedSettings do
  describe ".call" do
    it "returns global defaults when the profile has no overrides" do
      config = build_config(global: { "storage_backend" => "dashlane" }, profiles: {})

      expect(described_class.call(config: config, profile: "work"))
        .to eq("storage_backend" => "dashlane")
    end

    it "deep-merges profile overrides over global defaults" do
      config = build_config(
        global: { "storage_backend" => "dashlane", "oauth" => { "client_id" => "g" } },
        profiles: { "work" => { "storage_backend" => "keychain", "oauth" => { "client_secret_ref" => "p" } } }
      )

      expect(described_class.call(config: config, profile: "work")).to eq(
        "storage_backend" => "keychain",
        "oauth" => { "client_id" => "g", "client_secret_ref" => "p" }
      )
    end

    it "returns an empty hash when the config is empty" do
      expect(described_class.call(config: {}, profile: "work")).to eq({})
    end

    it "preserves arrays exactly (overwrites, never element-merges)" do
      config = build_config(
        global: { "scopes" => %w[a b] },
        profiles: { "work" => { "scopes" => %w[c] } }
      )

      expect(described_class.call(config: config, profile: "work")).to eq("scopes" => %w[c])
    end

    it "falls back to global defaults when the profile entry is absent" do
      config = build_config(global: { "x" => 1 }, profiles: { "other" => { "y" => 2 } })

      expect(described_class.call(config: config, profile: "work")).to eq("x" => 1)
    end

    it "raises ConfigError when the global node is not a mapping" do
      config = { "global" => 1, "profiles" => {} }

      expect { described_class.call(config: config, profile: "work") }
        .to raise_error(SlackStatusCli::Tokens::Errors::ConfigError, /global/)
    end

    it "raises ConfigError when the profiles node is not a mapping" do
      config = { "global" => {}, "profiles" => [] }

      expect { described_class.call(config: config, profile: "work") }
        .to raise_error(SlackStatusCli::Tokens::Errors::ConfigError, /profiles/)
    end

    it "raises ConfigError when the profile entry is not a mapping" do
      config = { "global" => {}, "profiles" => { "work" => 5 } }

      expect { described_class.call(config: config, profile: "work") }
        .to raise_error(SlackStatusCli::Tokens::Errors::ConfigError, /work/)
    end
  end
end
