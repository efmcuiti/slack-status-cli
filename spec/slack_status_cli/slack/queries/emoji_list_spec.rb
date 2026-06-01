require "spec_helper"

RSpec.describe SlackStatusCli::Slack::Queries::EmojiList do
  describe ".call" do
    let(:token) { "xoxp-test-token-1234" }

    it "hits emoji.list with bearer auth" do
      stub = stub_request(:get, "https://slack.com/api/emoji.list")
        .with(headers: { "Authorization" => "Bearer #{token}" })
        .to_return(status: 200, body: '{"ok":true,"emoji":{}}')

      described_class.call(token: token)

      expect(stub).to have_been_requested
    end

    it "returns the parsed JSON hash" do
      body = { "ok" => true, "emoji" => { "phoenix_ash" => "https://x/y.png", "wolf" => "alias:dog" } }
      stub_request(:get, "https://slack.com/api/emoji.list")
        .to_return(status: 200, body: body.to_json)

      expect(described_class.call(token: token)).to eq(body)
    end
  end
end
