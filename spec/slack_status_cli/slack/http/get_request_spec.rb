require "spec_helper"

RSpec.describe SlackStatusCli::Slack::Http::GetRequest do
  describe ".call" do
    let(:token) { "xoxp-test-token-1234" }

    it "GETs https://slack.com/api/<path> with bearer auth" do
      stub = stub_request(:get, "https://slack.com/api/auth.test")
        .with(headers: { "Authorization" => "Bearer #{token}" })
        .to_return(status: 200, body: '{"ok":true}')

      described_class.call(token: token, path: "auth.test")

      expect(stub).to have_been_requested
    end

    it "returns parsed JSON for a 200 response" do
      stub_request(:get, "https://slack.com/api/emoji.list")
        .to_return(status: 200, body: '{"ok":true,"emoji":{"foo":"https://x/y.png"}}')

      result = described_class.call(token: token, path: "emoji.list")

      expect(result).to eq("ok" => true, "emoji" => { "foo" => "https://x/y.png" })
    end

    it "raises a clear error on a non-200 response" do
      stub_request(:get, "https://slack.com/api/auth.test")
        .to_return(status: 500, body: "boom")

      expect { described_class.call(token: token, path: "auth.test") }
        .to raise_error(/Slack HTTP 500/)
    end

    it "raises on a transport failure" do
      stub_request(:get, "https://slack.com/api/auth.test")
        .to_raise(Errno::ECONNREFUSED)

      expect { described_class.call(token: token, path: "auth.test") }
        .to raise_error(Errno::ECONNREFUSED)
    end
  end
end
