require "spec_helper"

RSpec.describe SlackStatusCli::Slack::Queries::AuthTest do
  describe ".call" do
    let(:token) { "xoxp-test-token-1234" }

    it "hits auth.test with bearer auth" do
      stub = stub_request(:get, "https://slack.com/api/auth.test")
        .with(headers: { "Authorization" => "Bearer #{token}" })
        .to_return(status: 200, body: build_slack_auth_response.to_json)

      described_class.call(token: token)

      expect(stub).to have_been_requested
    end

    it "returns the parsed JSON hash on success" do
      auth = build_slack_auth_response(team: "Phoenix HQ", user: "efmcuiti")
      stub_request(:get, "https://slack.com/api/auth.test")
        .to_return(status: 200, body: auth.to_json)

      expect(described_class.call(token: token)).to eq(auth)
    end

    it "raises on a non-200 response" do
      stub_request(:get, "https://slack.com/api/auth.test")
        .to_return(status: 401, body: "invalid_auth")

      expect { described_class.call(token: token) }
        .to raise_error(/Slack HTTP 401/)
    end
  end
end
