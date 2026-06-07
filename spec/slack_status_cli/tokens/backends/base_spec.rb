require "spec_helper"

RSpec.describe SlackStatusCli::Tokens::Backends::Base do
  subject(:backend) { described_class.new(profile: "work") }

  describe "#initialize" do
    it "exposes the profile, settings, and a nil last_error" do
      backend = described_class.new(profile: "work", settings: { "token_ref" => "dl://x" })

      expect(backend.profile).to eq("work")
      expect(backend.settings).to eq("token_ref" => "dl://x")
      expect(backend.last_error).to be_nil
    end

    it "defaults settings to an empty hash" do
      expect(described_class.new(profile: "work").settings).to eq({})
    end
  end

  describe "#read" do
    it "raises NotImplementedError (abstract)" do
      expect { backend.read }.to raise_error(NotImplementedError)
    end
  end

  describe "#write" do
    it "raises NotImplementedError (abstract)" do
      expect { backend.write("xoxp-token") }.to raise_error(NotImplementedError)
    end
  end

  describe "#name" do
    it "returns the demodulized class name as a snake_case symbol" do
      stub_const("FakeKeychainBackend", Class.new(described_class))

      expect(FakeKeychainBackend.new(profile: "work").name).to eq(:fake_keychain_backend)
    end
  end

  describe "#source_label" do
    it "returns the demodulized class name as a humanized sentence" do
      stub_const("FakeKeychainBackend", Class.new(described_class))

      expect(FakeKeychainBackend.new(profile: "work").source_label).to eq("Fake keychain backend")
    end
  end

  describe "#location" do
    it "defaults to an empty string" do
      expect(backend.location).to eq("")
    end
  end

  describe "#not_found_hint" do
    it "defaults to nil" do
      expect(backend.not_found_hint).to be_nil
    end
  end
end
