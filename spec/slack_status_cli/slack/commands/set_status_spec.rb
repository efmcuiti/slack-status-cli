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
  end
end
