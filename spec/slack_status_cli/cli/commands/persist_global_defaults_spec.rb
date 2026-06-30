require "spec_helper"

RSpec.describe SlackStatusCli::Cli::Commands::PersistGlobalDefaults do
  describe ".call" do
    it "merges the defaults into config['global'] and persists them" do
      with_tmp_config do |path:, **|
        described_class.call(defaults: { "storage_backend" => "keychain" }, config_path: path)

        loaded = SlackStatusCli::Tokens::Queries::LoadConfig.call(path: path)
        expect(loaded.dig("global", "storage_backend")).to eq("keychain")
      end
    end

    it "deep-merges, preserving existing nested global keys" do
      with_tmp_config do |path:, **|
        SlackStatusCli::Tokens::Commands::WriteConfig.call(
          config: build_config(global: { "oauth" => { "client_id" => "cid" } }),
          path: path,
        )

        described_class.call(defaults: { "oauth" => { "client_secret_ref" => "ref" } }, config_path: path)

        loaded = SlackStatusCli::Tokens::Queries::LoadConfig.call(path: path)
        expect(loaded.dig("global", "oauth")).to eq("client_id" => "cid", "client_secret_ref" => "ref")
      end
    end

    it "creates the config file when its directory is missing" do
      with_tmp_config do |dir:, **|
        path = File.join(dir, "nested", "config.yml")

        described_class.call(defaults: { "storage_backend" => "file" }, config_path: path)

        expect(File.exist?(path)).to be(true)
      end
    end

    it "raises ConfigError when the existing 'global' node is not a mapping" do
      with_tmp_config do |path:, **|
        File.write(path, "global: 5\n")

        expect { described_class.call(defaults: { "storage_backend" => "file" }, config_path: path) }
          .to raise_error(SlackStatusCli::Tokens::Errors::ConfigError, /global/)
      end
    end
  end
end
