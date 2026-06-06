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

    it "delegates to RunMusicalLoop when the mode is :musical_myth" do
      expect(run_loop).to receive(:call).with(token: token, output: output)

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

    it "clears the status for an unknown mode (same result as :clear)" do
      expect(clear_status).to receive(:call).with(token: token, output: output)

      described_class.call(token: token, mode: :bogus, output: output)
    end
  end
end
