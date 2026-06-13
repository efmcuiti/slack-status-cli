require "spec_helper"

RSpec.describe SlackStatusCli::Tokens::Queries::NotFoundMessage do
  def without_env(key)
    had = ENV.key?(key)
    old = ENV[key]
    ENV.delete(key)
    yield
  ensure
    ENV[key] = old if had
  end

  def with_env(key, value)
    had = ENV.key?(key)
    old = ENV[key]
    ENV[key] = value
    yield
  ensure
    had ? ENV[key] = old : ENV.delete(key)
  end

  def env_backend(profile: "work")
    SlackStatusCli::Tokens::Backends::Env.new(profile: profile)
  end

  describe ".call" do
    it "mentions the profile name" do
      without_env("SLACK_SECRET_TOKEN") do
        message = described_class.call(
          profile: "work", config_path: "/cfg.yml", tried_backend: nil, profile_configured: false
        )

        expect(message).to include("profile 'work'")
      end
    end

    it "mentions the config path when an unconfigured non-default profile has no backend" do
      without_env("SLACK_SECRET_TOKEN") do
        message = described_class.call(
          profile: "work", config_path: "/home/me/config.yml", tried_backend: nil, profile_configured: false
        )

        expect(message).to include("not configured in /home/me/config.yml")
      end
    end

    it "names the tried backend and surfaces its not_found_hint" do
      without_env("SLACK_SECRET_TOKEN") do
        message = described_class.call(
          profile: "work", config_path: "/cfg.yml", tried_backend: env_backend, profile_configured: true
        )

        expect(message).to include("Tried Env but it returned no token.")
        expect(message).to include("Export SLACK_STATUS_TOKEN_WORK")
      end
    end

    it "omits the not-configured line when the profile is explicitly configured" do
      without_env("SLACK_SECRET_TOKEN") do
        message = described_class.call(
          profile: "work", config_path: "/cfg.yml", tried_backend: nil, profile_configured: true
        )

        expect(message).not_to include("not configured")
      end
    end

    it "always lists the three remediation steps using the profile-scoped env var" do
      without_env("SLACK_SECRET_TOKEN") do
        message = described_class.call(
          profile: "work", config_path: "/cfg.yml", tried_backend: nil, profile_configured: false
        )

        expect(message).to include("ruby slack_status.rb setup --profile work")
        expect(message).to include("export SLACK_STATUS_TOKEN_WORK=xoxp-")
        expect(message).to include("ruby slack_status.rb --token xoxp-... --profile work")
      end
    end

    it "appends the ignored SLACK_SECRET_TOKEN note for a non-default profile when it is set" do
      with_env("SLACK_SECRET_TOKEN", "xoxp-legacy") do
        message = described_class.call(
          profile: "work", config_path: "/cfg.yml", tried_backend: nil, profile_configured: false
        )

        expect(message).to include("SLACK_SECRET_TOKEN is set but intentionally ignored")
      end
    end

    it "does not append the legacy note for the unconfigured default profile" do
      with_env("SLACK_SECRET_TOKEN", "xoxp-legacy") do
        message = described_class.call(
          profile: "default", config_path: "/cfg.yml", tried_backend: nil, profile_configured: false
        )

        expect(message).not_to include("intentionally ignored")
      end
    end
  end
end
