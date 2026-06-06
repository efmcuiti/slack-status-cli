require "spec_helper"
require "json"
require "stringio"

RSpec.describe SlackStatusCli::Slack::Commands::ClearStatus do
  describe ".call" do
    let(:token) { "xoxp-test-token-1234" }
    let(:output) { StringIO.new }

    it "POSTs an empty status payload (text='', emoji='', expiration=0)" do
      stub = stub_request(:post, "https://slack.com/api/users.profile.set")
        .with(
          headers: { "Authorization" => "Bearer #{token}" },
          body: { profile: { status_text: "", status_emoji: "", status_expiration: 0 } }.to_json
        )
        .to_return(status: 200, body: '{"ok":true}')

      described_class.call(token: token, output: output)

      expect(stub).to have_been_requested
    end

    it "delegates to SetStatus with the empty-status arguments" do
      expect(SlackStatusCli::Slack::Commands::SetStatus)
        .to receive(:call).with(token: token, text: "", emoji: "", expiration: nil, output: output)

      described_class.call(token: token, output: output)
    end
  end
end
