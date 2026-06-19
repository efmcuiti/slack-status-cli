require "spec_helper"

RSpec.describe SlackStatusCli::Oauth::Commands::ExchangeCode do
  describe ".call" do
    let(:endpoint) { "https://slack.com/api/oauth.v2.access" }
    let(:args) do
      {
        code: "auth-code-1",
        client_id: "123.456",
        client_secret: "s3cr3t",
        redirect_uri: "http://localhost:53682/callback"
      }
    end

    it "POSTs the form-encoded code and redirect_uri to oauth.v2.access" do
      stub = stub_request(:post, endpoint)
        .with(body: { "code" => "auth-code-1", "redirect_uri" => "http://localhost:53682/callback" })
        .to_return(status: 200, body: build_oauth_access_response.to_json)

      described_class.call(**args)

      expect(stub).to have_been_requested
    end

    it "authenticates with HTTP Basic using the client id and secret" do
      stub = stub_request(:post, endpoint)
        .with(basic_auth: ["123.456", "s3cr3t"])
        .to_return(status: 200, body: build_oauth_access_response.to_json)

      described_class.call(**args)

      expect(stub).to have_been_requested
    end

    it "returns the token and identity fields on ok:true" do
      body = build_oauth_access_response(
        token: "xoxp-real",
        scope: "users.profile:write",
        user_id: "U999",
        team_id: "T999",
        team_name: "Phoenix HQ"
      )
      stub_request(:post, endpoint).to_return(status: 200, body: body.to_json)

      expect(described_class.call(**args)).to eq(
        token: "xoxp-real",
        scope: "users.profile:write",
        user_id: "U999",
        team_id: "T999",
        team_name: "Phoenix HQ"
      )
    end

    it "raises ExchangeFailed naming the Slack error on ok:false" do
      stub_request(:post, endpoint)
        .to_return(status: 200, body: { "ok" => false, "error" => "invalid_code" }.to_json)

      expect { described_class.call(**args) }
        .to raise_error(SlackStatusCli::Oauth::Errors::ExchangeFailed, /invalid_code/)
    end

    it "raises ExchangeFailed on a non-200 HTTP status" do
      stub_request(:post, endpoint).to_return(status: 502, body: "bad gateway")

      expect { described_class.call(**args) }
        .to raise_error(SlackStatusCli::Oauth::Errors::ExchangeFailed, /502/)
    end

    it "raises ExchangeFailed when ok:true but the access_token is missing" do
      stub_request(:post, endpoint)
        .to_return(status: 200, body: build_oauth_access_response(token: nil).to_json)

      expect { described_class.call(**args) }
        .to raise_error(SlackStatusCli::Oauth::Errors::ExchangeFailed, /no authed_user.access_token/)
    end

    it "raises ExchangeFailed when ok:true but the access_token is blank" do
      stub_request(:post, endpoint)
        .to_return(status: 200, body: build_oauth_access_response(token: "").to_json)

      expect { described_class.call(**args) }
        .to raise_error(SlackStatusCli::Oauth::Errors::ExchangeFailed, /no authed_user.access_token/)
    end
  end
end
