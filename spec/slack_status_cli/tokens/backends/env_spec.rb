require "spec_helper"

RSpec.describe SlackStatusCli::Tokens::Backends::Env do
  def build(profile: "work", settings: {})
    described_class.new(profile: profile, settings: settings)
  end

  def with_env(key, value)
    had = ENV.key?(key)
    old = ENV[key]
    ENV[key] = value
    yield
  ensure
    had ? ENV[key] = old : ENV.delete(key)
  end

  def without_env(key)
    had = ENV.key?(key)
    old = ENV[key]
    ENV.delete(key)
    yield
  ensure
    ENV[key] = old if had
  end

  describe "#read" do
    it "returns the profile-scoped env var, stripped" do
      with_env("SLACK_STATUS_TOKEN_WORK", "  xoxp-from-env  ") do
        expect(build(profile: "work").read).to eq("xoxp-from-env")
      end
    end

    it "returns nil and records last_error when the env var is unset" do
      without_env("SLACK_STATUS_TOKEN_WORK") do
        backend = build(profile: "work")

        expect(backend.read).to be_nil
        expect(backend.last_error).to match(/SLACK_STATUS_TOKEN_WORK/)
      end
    end

    it "returns nil when the env var is set but blank" do
      with_env("SLACK_STATUS_TOKEN_WORK", "   ") do
        expect(build(profile: "work").read).to be_nil
      end
    end

    it "honors an explicit env var name from backend_options" do
      settings = { "backend_options" => { "env" => { "var" => "MY_CUSTOM_TOKEN" } } }
      with_env("MY_CUSTOM_TOKEN", "xoxp-custom") do
        expect(build(settings: settings).read).to eq("xoxp-custom")
      end
    end
  end

  describe "#write" do
    it "raises ManualWriteRequired (env vars are not writable here)" do
      expect { build.write("xoxp-new") }
        .to raise_error(
          SlackStatusCli::Tokens::Errors::ManualWriteRequired,
          /SLACK_STATUS_TOKEN_WORK/
        )
    end
  end

  describe "#location" do
    it "returns the profile-derived env var name" do
      expect(build(profile: "work").location).to eq("SLACK_STATUS_TOKEN_WORK")
    end

    it "sanitizes non-alphanumeric characters in the profile name" do
      expect(build(profile: "my work").location).to eq("SLACK_STATUS_TOKEN_MY_WORK")
    end

    it "returns the override var name when configured" do
      settings = { "backend_options" => { "env" => { "var" => "MY_CUSTOM_TOKEN" } } }

      expect(build(settings: settings).location).to eq("MY_CUSTOM_TOKEN")
    end
  end

  describe "identity" do
    it "exposes a snake_case name and a humanized source_label" do
      expect(build.name).to eq(:env)
      expect(build.source_label).to eq("Env")
    end
  end
end
