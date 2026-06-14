require "spec_helper"
require "uri"

RSpec.describe SlackStatusCli::Oauth::Queries::AuthorizeUrl do
  describe ".call" do
    let(:url) do
      described_class.call(
        client_id: "123.456",
        redirect_uri: "http://localhost:53682/callback",
        scopes: %w[users.profile:write emoji:read],
        state: "abc123"
      )
    end

    def params(raw)
      URI.decode_www_form(URI(raw).query).to_h
    end

    it "points at Slack's oauth/v2/authorize endpoint" do
      expect(url).to start_with("https://slack.com/oauth/v2/authorize?")
    end

    it "includes the given client_id" do
      expect(params(url)).to include("client_id" => "123.456")
    end

    it "percent-encodes the redirect_uri in the raw query string" do
      expect(url).to include("redirect_uri=http%3A%2F%2Flocalhost%3A53682%2Fcallback")
    end

    it "round-trips the redirect_uri when the query is decoded" do
      expect(params(url)).to include("redirect_uri" => "http://localhost:53682/callback")
    end

    it "joins scopes with commas in the user_scope param" do
      expect(params(url)).to include("user_scope" => "users.profile:write,emoji:read")
    end

    it "includes the state param" do
      expect(params(url)).to include("state" => "abc123")
    end
  end
end
