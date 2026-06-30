require "spec_helper"

RSpec.describe SlackStatusCli::Cli::Commands::DottedSet do
  describe ".call" do
    it "sets a top-level key and returns the mutated hash" do
      hash = {}
      result = described_class.call(hash: hash, key: "backend", value: "keychain")
      expect(result).to eq("backend" => "keychain")
      expect(result).to be(hash)
    end

    it "creates intermediate hashes for a dotted key" do
      expect(described_class.call(hash: {}, key: "global.oauth.client_id", value: "cid"))
        .to eq("global" => { "oauth" => { "client_id" => "cid" } })
    end

    it "overwrites an existing leaf without discarding siblings" do
      hash = { "global" => { "oauth" => { "client_id" => "old" }, "storage_backend" => "file" } }
      described_class.call(hash: hash, key: "global.oauth.client_id", value: "new")
      expect(hash).to eq(
        "global" => { "oauth" => { "client_id" => "new" }, "storage_backend" => "file" },
      )
    end

    it "replaces a non-hash intermediate value with a hash" do
      hash = { "global" => "scalar" }
      described_class.call(hash: hash, key: "global.oauth.client_id", value: "cid")
      expect(hash).to eq("global" => { "oauth" => { "client_id" => "cid" } })
    end
  end
end
