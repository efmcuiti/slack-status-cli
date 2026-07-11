require "spec_helper"
require "stringio"

RSpec.describe SlackStatusCli::Telemetry::NullLogger do
  describe "#rich_log" do
    it "returns nil" do
      expect(described_class.new.rich_log(message: "ignored")).to be_nil
    end

    it "writes nothing to its io" do
      io = StringIO.new

      described_class.new(io: io).rich_log(message: "ignored", tags: { a: 1 }, level: :error)

      expect(io.string).to be_empty
    end

    it "shares the StructuredLogger surface as the no-op off switch" do
      expect(described_class.ancestors).to include(SlackStatusCli::Telemetry::StructuredLogger)
    end
  end
end
