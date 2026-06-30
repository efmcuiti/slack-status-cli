require "spec_helper"

RSpec.describe SlackStatusCli::Cli::Queries::DottedGet do
  describe ".call" do
    it "returns the leaf value for a dotted key when every level matches" do
      hash = { "global" => { "defaults" => { "profile" => "work" } } }
      expect(described_class.call(hash: hash, key: "global.defaults.profile")).to eq("work")
    end

    it "returns nil when an intermediate key is missing" do
      hash = { "global" => { "defaults" => {} } }
      expect(described_class.call(hash: hash, key: "global.defaults.profile")).to be_nil
    end

    it "returns nil when an intermediate value is not a Hash" do
      hash = { "global" => "not-a-hash" }
      expect(described_class.call(hash: hash, key: "global.defaults.profile")).to be_nil
    end

    it "returns the top-level value for a key with no dots" do
      hash = { "storage_backend" => "keychain" }
      expect(described_class.call(hash: hash, key: "storage_backend")).to eq("keychain")
    end
  end
end
