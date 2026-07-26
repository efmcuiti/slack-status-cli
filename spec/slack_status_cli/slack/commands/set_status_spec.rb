require "spec_helper"
require "json"
require "stringio"

RSpec.describe SlackStatusCli::Slack::Commands::SetStatus do
  describe ".call" do
    let(:token) { "xoxp-test-token-1234" }
    let(:output) { StringIO.new }

    it "POSTs the expected JSON payload to users.profile.set" do
      stub = stub_request(:post, "https://slack.com/api/users.profile.set")
        .with(
          headers: { "Authorization" => "Bearer #{token}" },
          body: { profile: { status_text: "heads down", status_emoji: ":wolf:", status_expiration: 0 } }.to_json
        )
        .to_return(status: 200, body: '{"ok":true}')

      described_class.call(token: token, text: "heads down", emoji: ":wolf:", expiration: nil, output: output)

      expect(stub).to have_been_requested
    end

    it "expands a relative expiration via Builders::StatusPayload" do
      now = Time.at(1_700_000_000)
      stub = stub_request(:post, "https://slack.com/api/users.profile.set")
        .with(
          body: { profile: { status_text: "lunch", status_emoji: ":meat_on_bone:", status_expiration: now.to_i + (30 * 60) } }.to_json
        )
        .to_return(status: 200, body: '{"ok":true}')

      described_class.call(token: token, text: "lunch", emoji: ":meat_on_bone:", expiration: "30m", now: now, output: output)

      expect(stub).to have_been_requested
    end

    it "delegates response logging to Formatters::ResponseLogger" do
      stub_request(:post, "https://slack.com/api/users.profile.set")
        .to_return(status: 200, body: '{"ok":true}')
      expect(SlackStatusCli::Slack::Formatters::ResponseLogger)
        .to receive(:call).with(response: instance_of(Net::HTTPOK), output: output)

      described_class.call(token: token, text: "heads down", emoji: ":wolf:", expiration: nil, output: output)
    end

    it "returns the raw Net::HTTPResponse" do
      stub_request(:post, "https://slack.com/api/users.profile.set")
        .to_return(status: 200, body: '{"ok":true}')

      response = described_class.call(token: token, text: "", emoji: "", expiration: nil, output: output)

      expect(response).to be_a(Net::HTTPResponse)
    end

    describe "pre-send status log line" do
      it "prints the message before POSTing, for a non-empty status" do
        stub_request(:post, "https://slack.com/api/users.profile.set")
          .to_return(status: 200, body: '{"ok":true}')

        described_class.call(token: token, text: "heads down", emoji: ":wolf:", expiration: nil, output: output)

        expect(output.string).to match(/📤 Setting Slack status: :wolf: heads down.*✅ Slack status updated!/m)
      end

      it "omits the emoji cleanly when the emoji is blank (no dangling space)" do
        stub_request(:post, "https://slack.com/api/users.profile.set")
          .to_return(status: 200, body: '{"ok":true}')

        described_class.call(token: token, text: "heads down", emoji: "", expiration: nil, output: output)

        expect(output.string).to include("📤 Setting Slack status: heads down")
        expect(output.string).not_to match(/Setting Slack status:  /)
      end

      it "prints a clearing line when the text is empty" do
        stub_request(:post, "https://slack.com/api/users.profile.set")
          .to_return(status: 200, body: '{"ok":true}')

        described_class.call(token: token, text: "", emoji: "", expiration: nil, output: output)

        expect(output.string).to include("📤 Clearing Slack status (empty)")
        expect(output.string).not_to include("📤 Setting Slack status")
      end

      it "prints the pre-send line even when the POST fails (intent, not outcome)" do
        allow(SlackStatusCli::Slack::Http::PostRequest).to receive(:call).and_raise(StandardError, "boom")

        expect do
          described_class.call(token: token, text: "heads down", emoji: ":wolf:", expiration: nil, output: output)
        end.to raise_error(StandardError)

        expect(output.string).to include("📤 Setting Slack status: :wolf: heads down")
        expect(output.string).not_to include("✅ Slack status updated!")
      end

      it "never emits the token on the pre-send line" do
        stub_request(:post, "https://slack.com/api/users.profile.set")
          .to_return(status: 200, body: '{"ok":true}')

        described_class.call(token: token, text: "heads down", emoji: ":wolf:", expiration: nil, output: output)

        expect(output.string).not_to include(token)
      end
    end
  end
end
