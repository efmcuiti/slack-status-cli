require "spec_helper"

RSpec.describe SlackStatusCli::Tokens::Queries::ResolveToken do
  def with_env(key, value)
    had = ENV.key?(key)
    old = ENV[key]
    ENV[key] = value
    yield
  ensure
    had ? ENV[key] = old : ENV.delete(key)
  end

  def without_env(*keys)
    saved = keys.map { |key| [key, ENV.key?(key), ENV[key]] }
    keys.each { |key| ENV.delete(key) }
    yield
  ensure
    saved.each { |key, had, old| had ? ENV[key] = old : ENV.delete(key) }
  end

  def write_token_file(path, contents)
    File.write(path, "#{contents}\n")
    File.chmod(0o600, path)
  end

  describe ".call" do
    it "returns the cli_token first, stripped, when present" do
      without_env("SLACK_STATUS_TOKEN_WORK", "SLACK_SECRET_TOKEN") do
        result = described_class.call(profile: "work", cli_token: "  xoxp-cli  ", config_path: "/no/such.yml")

        expect(result).to eq(token: "xoxp-cli", source: "cli:--token", profile: "work")
      end
    end

    it "returns the profile-scoped ENV var when there is no cli_token" do
      without_env("SLACK_SECRET_TOKEN") do
        with_env("SLACK_STATUS_TOKEN_WORK", "xoxp-env") do
          result = described_class.call(profile: "work", config_path: "/no/such.yml")

          expect(result).to eq(token: "xoxp-env", source: "env:SLACK_STATUS_TOKEN_WORK", profile: "work")
        end
      end
    end

    it "reads from the configured backend when neither cli_token nor ENV are set" do
      without_env("SLACK_STATUS_TOKEN_WORK", "SLACK_SECRET_TOKEN") do
        with_tmp_config do |path:, dir:|
          token_path = File.join(dir, "work.token")
          write_token_file(token_path, "xoxp-file")
          config = build_config(profiles: {
            "work" => { "storage_backend" => "file", "backend_options" => { "file" => { "path" => token_path } } }
          })
          SlackStatusCli::Tokens::Commands::WriteConfig.call(config: config, path: path)

          result = described_class.call(profile: "work", config_path: path)

          expect(result).to eq(token: "xoxp-file", source: "File", profile: "work")
        end
      end
    end

    it "honors the backend chosen by merged settings (profile overrides global)" do
      without_env("SLACK_STATUS_TOKEN_WORK", "SLACK_SECRET_TOKEN") do
        with_tmp_config do |path:, dir:|
          token_path = File.join(dir, "work.token")
          write_token_file(token_path, "xoxp-from-file")
          config = build_config(
            global: { "storage_backend" => "env" },
            profiles: {
              "work" => { "storage_backend" => "file", "backend_options" => { "file" => { "path" => token_path } } }
            }
          )
          SlackStatusCli::Tokens::Commands::WriteConfig.call(config: config, path: path)

          result = described_class.call(profile: "work", config_path: path)

          expect(result[:token]).to eq("xoxp-from-file")
        end
      end
    end

    it "raises NotFoundError carrying the friendly NotFoundMessage when nothing resolves" do
      without_env("SLACK_STATUS_TOKEN_GHOST", "SLACK_SECRET_TOKEN") do
        expect { described_class.call(profile: "ghost", config_path: "/no/such.yml") }
          .to raise_error(SlackStatusCli::Tokens::Errors::NotFoundError, /No Slack token found for profile 'ghost'/)
      end
    end

    it "falls back to SLACK_SECRET_TOKEN only for the unconfigured default profile" do
      without_env("SLACK_STATUS_TOKEN_DEFAULT") do
        with_env("SLACK_SECRET_TOKEN", "xoxp-legacy") do
          result = described_class.call(profile: "default", config_path: "/no/such.yml")

          expect(result).to eq(token: "xoxp-legacy", source: "env:SLACK_SECRET_TOKEN", profile: "default")
        end
      end
    end

    it "ignores SLACK_SECRET_TOKEN for a non-default profile" do
      without_env("SLACK_STATUS_TOKEN_WORK") do
        with_env("SLACK_SECRET_TOKEN", "xoxp-legacy") do
          expect { described_class.call(profile: "work", config_path: "/no/such.yml") }
            .to raise_error(SlackStatusCli::Tokens::Errors::NotFoundError)
        end
      end
    end

    it "raises ConfigError for an unknown storage_backend" do
      without_env("SLACK_STATUS_TOKEN_WORK", "SLACK_SECRET_TOKEN") do
        with_tmp_config do |path:, **|
          config = build_config(profiles: { "work" => { "storage_backend" => "bogus" } })
          SlackStatusCli::Tokens::Commands::WriteConfig.call(config: config, path: path)

          expect { described_class.call(profile: "work", config_path: path) }
            .to raise_error(SlackStatusCli::Tokens::Errors::ConfigError, /bogus/)
        end
      end
    end
  end
end
