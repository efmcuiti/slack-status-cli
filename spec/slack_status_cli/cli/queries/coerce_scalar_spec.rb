require "spec_helper"

RSpec.describe SlackStatusCli::Cli::Queries::CoerceScalar do
  describe ".call" do
    it "returns true for 'true' and 'yes'" do
      expect(described_class.call(value: "true")).to be(true)
      expect(described_class.call(value: "yes")).to be(true)
    end

    it "returns false for 'false' and 'no'" do
      expect(described_class.call(value: "false")).to be(false)
      expect(described_class.call(value: "no")).to be(false)
    end

    it "returns nil for 'null' and 'nil'" do
      expect(described_class.call(value: "null")).to be_nil
      expect(described_class.call(value: "nil")).to be_nil
    end

    it "returns an Integer for an integer-shaped string" do
      expect(described_class.call(value: "42")).to eq(42)
      expect(described_class.call(value: "-7")).to eq(-7)
    end

    it "returns a Float for a float-shaped string" do
      expect(described_class.call(value: "3.14")).to eq(3.14)
      expect(described_class.call(value: "-0.5")).to eq(-0.5)
    end

    it "returns the original string for anything else" do
      expect(described_class.call(value: "keychain")).to eq("keychain")
    end
  end
end
