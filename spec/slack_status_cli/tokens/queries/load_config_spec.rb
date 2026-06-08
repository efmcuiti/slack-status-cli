require "spec_helper"

RSpec.describe SlackStatusCli::Tokens::Queries::LoadConfig do
  describe ".call" do
    it "returns an empty hash when the path is missing" do
      with_tmp_config do |dir:, **|
        expect(described_class.call(path: File.join(dir, "absent.yml"))).to eq({})
      end
    end

    it "returns the parsed hash when the path exists" do
      with_tmp_config do |path:, **|
        File.write(path, "global:\n  storage_backend: keychain\nprofiles: {}\n")

        expect(described_class.call(path: path)).to eq(
          "global" => { "storage_backend" => "keychain" },
          "profiles" => {}
        )
      end
    end

    it "deep-stringifies non-string keys" do
      with_tmp_config do |path:, **|
        File.write(path, "1: one\n2: two\n")

        expect(described_class.call(path: path)).to eq("1" => "one", "2" => "two")
      end
    end

    it "returns an empty hash when the file is empty" do
      with_tmp_config do |path:, **|
        File.write(path, "")

        expect(described_class.call(path: path)).to eq({})
      end
    end

    it "raises ConfigError on malformed YAML" do
      with_tmp_config do |path:, **|
        File.write(path, "global: [1, 2\nprofiles:\n")

        expect { described_class.call(path: path) }
          .to raise_error(SlackStatusCli::Tokens::Errors::ConfigError, /Failed to parse/)
      end
    end

    it "defaults to the Tokens default config path" do
      expect(described_class.new.path).to eq(SlackStatusCli::Tokens::Constants::DEFAULT_CONFIG_PATH)
    end
  end
end
