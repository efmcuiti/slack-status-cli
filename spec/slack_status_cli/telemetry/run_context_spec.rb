require "spec_helper"

RSpec.describe SlackStatusCli::Telemetry::RunContext do
  describe ".generate" do
    it "returns a non-empty hex string" do
      run_id = described_class.generate

      expect(run_id).to match(/\A[0-9a-f]+\z/)
      expect(run_id).not_to be_empty
    end

    it "returns a fresh, unique id on each call" do
      expect(described_class.generate).not_to eq(described_class.generate)
    end

    it "defaults to a 16-character (8-byte) id" do
      expect(described_class.generate.length).to eq(16)
    end
  end
end
