require "spec_helper"

RSpec.describe SlackStatusCli::Slack::Http::PostRequest do
  describe ".call" do
    let(:token) { "xoxp-test-token-1234" }
    let(:body) { '{"profile":{"status_text":"heads down"}}' }

    it "POSTs to https://slack.com/api/<path> with bearer auth and the body" do
      stub = stub_request(:post, "https://slack.com/api/users.profile.set")
        .with(headers: { "Authorization" => "Bearer #{token}" }, body: body)
        .to_return(status: 200, body: '{"ok":true}')

      described_class.call(token: token, path: "users.profile.set", body: body)

      expect(stub).to have_been_requested
    end

    it "sets Content-Type: application/json; charset=utf-8" do
      stub = stub_request(:post, "https://slack.com/api/users.profile.set")
        .with(headers: { "Content-Type" => "application/json; charset=utf-8" })
        .to_return(status: 200, body: '{"ok":true}')

      described_class.call(token: token, path: "users.profile.set", body: body)

      expect(stub).to have_been_requested
    end

    it "returns the raw Net::HTTPResponse for the caller to log" do
      stub_request(:post, "https://slack.com/api/users.profile.set")
        .to_return(status: 200, body: '{"ok":true}')

      response = described_class.call(token: token, path: "users.profile.set", body: body)

      expect(response).to be_a(Net::HTTPResponse)
      expect(response.body).to eq('{"ok":true}')
    end
  end
end
