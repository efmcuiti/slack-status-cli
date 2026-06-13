require "spec_helper"

RSpec.describe SlackStatusCli::Tokens::Queries::NotFoundMessage do
  def env_backend(profile: "work")
    SlackStatusCli::Tokens::Backends::Env.new(profile: profile)
  end

  describe ".call" do
    it "mentions the profile name" do
      message = described_class.call(
        profile: "work", config_path: "/cfg.yml", tried_backend: nil, profile_configured: false
      )

      expect(message).to include("profile 'work'")
    end

    it "mentions the config path when an unconfigured non-default profile has no backend" do
      message = described_class.call(
        profile: "work", config_path: "/home/me/config.yml", tried_backend: nil, profile_configured: false
      )

      expect(message).to include("not configured in /home/me/config.yml")
    end

    it "names the tried backend and surfaces its not_found_hint" do
      message = described_class.call(
        profile: "work", config_path: "/cfg.yml", tried_backend: env_backend, profile_configured: true
      )

      expect(message).to include("Tried Env but it returned no token.")
      expect(message).to include("Export SLACK_STATUS_TOKEN_WORK")
    end

    it "omits the not-configured line when the profile is explicitly configured" do
      message = described_class.call(
        profile: "work", config_path: "/cfg.yml", tried_backend: nil, profile_configured: true
      )

      expect(message).not_to include("not configured")
    end

    it "always lists the three remediation steps using the profile-scoped env var" do
      message = described_class.call(
        profile: "work", config_path: "/cfg.yml", tried_backend: nil, profile_configured: false
      )

      expect(message).to include("ruby slack_status.rb setup --profile work")
      expect(message).to include("export SLACK_STATUS_TOKEN_WORK=xoxp-")
      expect(message).to include("ruby slack_status.rb --token xoxp-... --profile work")
    end

    it "appends the ignored SLACK_SECRET_TOKEN note for a non-default profile when legacy_env_present" do
      message = described_class.call(
        profile: "work", config_path: "/cfg.yml", tried_backend: nil,
        profile_configured: false, legacy_env_present: true
      )

      expect(message).to include("SLACK_SECRET_TOKEN is set but intentionally ignored")
    end

    it "does not append the legacy note for the unconfigured default profile" do
      message = described_class.call(
        profile: "default", config_path: "/cfg.yml", tried_backend: nil,
        profile_configured: false, legacy_env_present: true
      )

      expect(message).not_to include("intentionally ignored")
    end

    it "does not append the legacy note when legacy_env_present is false" do
      message = described_class.call(
        profile: "work", config_path: "/cfg.yml", tried_backend: nil,
        profile_configured: false, legacy_env_present: false
      )

      expect(message).not_to include("intentionally ignored")
    end
  end
end
