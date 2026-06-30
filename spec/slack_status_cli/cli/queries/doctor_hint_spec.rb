require "spec_helper"

RSpec.describe SlackStatusCli::Cli::Queries::DoctorHint do
  describe ".call" do
    it "returns a re-run setup hint for an auth failure" do
      hint = described_class.call(diagnosis: "invalid_auth")
      expect(hint).to be_a(String)
      expect(hint).to include("setup")
    end

    it "returns a scope hint for missing_scope" do
      hint = described_class.call(diagnosis: "missing_scope")
      expect(hint).to include("users.profile:write")
    end

    it "returns nil for an unrecognized diagnosis" do
      expect(described_class.call(diagnosis: "totally_unknown")).to be_nil
    end
  end
end
