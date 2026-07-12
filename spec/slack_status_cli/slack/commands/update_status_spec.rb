require "spec_helper"
require "stringio"

RSpec.describe SlackStatusCli::Slack::Commands::UpdateStatus do
  describe ".call" do
    let(:token) { "xoxp-test-token-1234" }
    let(:output) { StringIO.new }
    let(:clear_status) { SlackStatusCli::Slack::Commands::ClearStatus }
    let(:run_loop) { SlackStatusCli::Slack::Commands::RunMusicalLoop }
    let(:set_status) { SlackStatusCli::Slack::Commands::SetStatus }
    let(:mode_status) { SlackStatusCli::Slack::Builders::ModeStatus }

    it "delegates to ClearStatus when the mode is :clear" do
      expect(clear_status).to receive(:call).with(token: token, output: output)

      described_class.call(token: token, mode: :clear, output: output)
    end

    it "delegates to RunMusicalLoop when the mode is :musical_myth, forwarding telemetry" do
      telemetry = SlackStatusCli::Telemetry::NullLogger.new
      expect(run_loop).to receive(:call).with(token: token, output: output, telemetry: telemetry)

      described_class.call(token: token, mode: :musical_myth, output: output, telemetry: telemetry)
    end

    it "defaults telemetry to a NullLogger when none is injected" do
      expect(run_loop).to receive(:call)
        .with(token: token, output: output, telemetry: an_instance_of(SlackStatusCli::Telemetry::NullLogger))

      described_class.call(token: token, mode: :musical_myth, output: output)
    end

    it "sets the status from ModeStatus output for a known mode" do
      allow(mode_status).to receive(:call).with(mode: :myth)
        .and_return(text: "", emoji: ":wolf:", expiration: nil)
      expect(set_status).to receive(:call).with(
        token: token, text: "", emoji: ":wolf:", expiration: nil, output: output
      )

      described_class.call(token: token, mode: :myth, output: output)
    end

    it "prefers explicit text/emoji/expiration over the mode defaults" do
      allow(mode_status).to receive(:call).with(mode: :lunch)
        .and_return(text: "default", emoji: ":meat_on_bone:", expiration: 111)
      expect(set_status).to receive(:call).with(
        token: token, text: "Heads down", emoji: ":wolf:", expiration: "30m", output: output
      )

      described_class.call(
        token: token, mode: :lunch, text: "Heads down", emoji: ":wolf:", expiration: "30m", output: output
      )
    end

    it "sets a custom freeform status from the explicit args for an unknown mode" do
      expect(set_status).to receive(:call).with(
        token: token, text: "Deep in the code", emoji: ":fire:", expiration: "1h", output: output
      )

      described_class.call(
        token: token, mode: :custom, text: "Deep in the code", emoji: ":fire:", expiration: "1h", output: output
      )
    end

    it "falls back to an empty status for an unknown mode given no args" do
      expect(set_status).to receive(:call).with(
        token: token, text: "", emoji: "", expiration: nil, output: output
      )

      described_class.call(token: token, mode: :bogus, output: output)
    end
  end
end
