require "spec_helper"

RSpec.describe SlackStatusCli::Oauth::Commands::Install do
  let(:exchange_result) do
    { token: "xoxp-user-token", scope: "users.profile:write", user_id: "U1", team_id: "T1", team_name: "Phoenix HQ" }
  end

  def stub_flow(exchange: exchange_result, raise_exchange: nil)
    allow(SlackStatusCli::Oauth::Queries::AuthorizeUrl).to receive(:call).and_return("https://slack.com/oauth/v2/authorize?x=1")
    allow(SlackStatusCli::Oauth::Commands::WaitForCallback).to receive(:call).and_return({ code: "auth-code" })
    if raise_exchange
      allow(SlackStatusCli::Oauth::Commands::ExchangeCode).to receive(:call).and_raise(raise_exchange)
    else
      allow(SlackStatusCli::Oauth::Commands::ExchangeCode).to receive(:call).and_return(exchange)
    end
  end

  def install(telemetry:)
    described_class.call(
      client_id: "cid", client_secret: "csecret", scopes: "users.profile:write",
      port: 53682, timeout: 60, telemetry: telemetry
    )
  end

  describe ".call" do
    it "emits a start event with the port and scopes normalized to a comma-joined string" do
      stub_flow
      telemetry = CapturingTelemetry.new

      described_class.call(
        client_id: "cid", client_secret: "csecret", scopes: ["users.profile:write", "emoji:read"],
        port: 53682, timeout: 60, telemetry: telemetry
      )

      expect(telemetry.entry_for("oauth install started").tags)
        .to include(port: 53682, scopes: "users.profile:write,emoji:read")
    end

    it "emits a token-exchanged event with the identity but never the token" do
      stub_flow
      telemetry = CapturingTelemetry.new

      install(telemetry: telemetry)

      entry = telemetry.entry_for("oauth token exchanged")
      expect(entry.tags).to include(user_id: "U1", team_id: "T1", team_name: "Phoenix HQ")
      expect(entry.tags).not_to have_key(:token)
    end

    it "emits a scope-granted event carrying the granted scope" do
      stub_flow
      telemetry = CapturingTelemetry.new

      install(telemetry: telemetry)

      expect(telemetry.entry_for("oauth scope granted").tags).to include(scope: "users.profile:write")
    end

    it "never puts the token in any telemetry tag (scrub-independent)" do
      stub_flow
      telemetry = CapturingTelemetry.new

      install(telemetry: telemetry)

      expect(telemetry.entries.flat_map { |entry| entry.tags.values }).not_to include("xoxp-user-token")
    end

    it "logs an error event and re-raises when the exchange fails" do
      stub_flow(raise_exchange: SlackStatusCli::Oauth::Errors::ExchangeFailed.new("Slack HTTP 400: bad_code"))
      telemetry = CapturingTelemetry.new

      expect { install(telemetry: telemetry) }.to raise_error(SlackStatusCli::Oauth::Errors::ExchangeFailed)

      entry = telemetry.entry_for("oauth token exchange failed")
      expect(entry.level).to eq(:error)
      expect(entry.tags[:reason]).to include("bad_code")
    end

    it "also logs and re-raises a non-Errors::Error failure (e.g. a network error), scrubbing the reason" do
      stub_flow(raise_exchange: StandardError.new("connection reset leaked xoxp-abcd1234efgh"))
      telemetry = CapturingTelemetry.new

      expect { install(telemetry: telemetry) }.to raise_error(StandardError, /connection reset/)

      entry = telemetry.entry_for("oauth token exchange failed")
      expect(entry.level).to eq(:error)
      expect(entry.tags[:reason]).to include("connection reset")
      expect(entry.tags[:reason]).not_to include("xoxp-abcd1234efgh")
    end

    it "works with the NullLogger default (no telemetry: argument)" do
      stub_flow

      expect do
        described_class.call(client_id: "cid", client_secret: "csecret", scopes: "s", port: 1, timeout: 1)
      end.not_to raise_error
    end
  end
end
