require "spec_helper"
require "json"

RSpec.describe SlackStatusCli::Cli::Queries::ResolveTelemetry do
  describe ".call" do
    context "when SLACK_STATUS_LOG is off" do
      it "returns a NullLogger when unset" do
        expect(described_class.call(env: {})).to be_an_instance_of(SlackStatusCli::Telemetry::NullLogger)
      end

      it "returns a NullLogger when empty" do
        expect(described_class.call(env: { "SLACK_STATUS_LOG" => "" }))
          .to be_an_instance_of(SlackStatusCli::Telemetry::NullLogger)
      end

      it "returns a NullLogger for 'off' (case/whitespace insensitive)" do
        expect(described_class.call(env: { "SLACK_STATUS_LOG" => "  OFF  " }))
          .to be_an_instance_of(SlackStatusCli::Telemetry::NullLogger)
      end

      it "stays off for an unrecognized value (e.g. a typo like 'josn')" do
        expect(described_class.call(env: { "SLACK_STATUS_LOG" => "josn" }))
          .to be_an_instance_of(SlackStatusCli::Telemetry::NullLogger)
      end
    end

    context "when SLACK_STATUS_LOG enables logging" do
      it "returns a StructuredLogger for a bare log level like 'warn'" do
        expect(described_class.call(env: { "SLACK_STATUS_LOG" => "warn" }))
          .to be_an_instance_of(SlackStatusCli::Telemetry::StructuredLogger)
      end

      it "returns a StructuredLogger writing to $stderr with a run_id set" do
        captured = capture_stdio do
          logger = described_class.call(env: { "SLACK_STATUS_LOG" => "json" })
          expect(logger).to be_an_instance_of(SlackStatusCli::Telemetry::StructuredLogger)
          logger.rich_log(message: "hello")
        end

        line = JSON.parse(captured[:stderr])
        expect(line["run_id"]).to be_a(String)
        expect(line["run_id"]).not_to be_empty
        expect(captured[:stdout]).to be_empty
      end

      it "wires SecretScrubber on the real path so a token never reaches the line" do
        captured = capture_stdio do
          described_class.call(env: { "SLACK_STATUS_LOG" => "json" }).rich_log(message: "leaked xoxp-abcd1234efgh")
        end

        expect(captured[:stderr]).not_to include("xoxp-abcd1234efgh")
        expect(captured[:stderr]).to include("xox?-…efgh")
      end
    end
  end
end
