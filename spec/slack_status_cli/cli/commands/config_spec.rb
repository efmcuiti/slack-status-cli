require "spec_helper"
require "stringio"
require "json"

RSpec.describe SlackStatusCli::Cli::Commands::Config do
  let(:output) { StringIO.new }

  # Records what it was asked to read so delegation can be asserted without
  # reaching into the real DottedGet.
  let(:recording_getter) do
    Class.new do
      attr_reader :calls
      def initialize
        @calls = []
      end

      def call(hash:, key:)
        @calls << { hash: hash, key: key }
        "resolved-value"
      end
    end.new
  end

  describe ".call(args: ['path'])" do
    it "prints the config path from options[:config_path]" do
      described_class.call(args: ["path"], options: { config_path: "/tmp/custom.yml" }, output: output)
      expect(output.string).to include("/tmp/custom.yml")
    end

    it "falls back to the default config path when none is given" do
      described_class.call(args: ["path"], options: {}, output: output)
      expect(output.string.strip).to eq(SlackStatusCli::Tokens::Constants::DEFAULT_CONFIG_PATH)
    end
  end

  describe ".call(args: ['get', ...])" do
    it "delegates to the getter and prints the resolved scalar" do
      with_tmp_config do |path:, **|
        SlackStatusCli::Tokens::Commands::WriteConfig.call(
          config: build_config(global: { "storage_backend" => "file" }), path: path,
        )

        described_class.call(
          args: ["get", "global.storage_backend"],
          options: { config_path: path },
          output: output,
          getter: recording_getter,
        )

        expect(recording_getter.calls.first[:key]).to eq("global.storage_backend")
        expect(output.string.strip).to eq("resolved-value")
      end
    end

    it "pretty-prints a Hash/Array value as JSON" do
      with_tmp_config do |path:, **|
        SlackStatusCli::Tokens::Commands::WriteConfig.call(
          config: build_config(global: { "oauth" => { "client_id" => "cid" } }), path: path,
        )

        described_class.call(
          args: ["get", "global.oauth"],
          options: { config_path: path },
          output: output,
        )

        expect(JSON.parse(output.string)).to eq("client_id" => "cid")
      end
    end

    it "raises ConfigKeyUnset when the key resolves to nil" do
      with_tmp_config do |path:, **|
        SlackStatusCli::Tokens::Commands::WriteConfig.call(config: build_config, path: path)

        expect {
          described_class.call(args: ["get", "global.nope"], options: { config_path: path }, output: output)
        }.to raise_error(SlackStatusCli::Cli::Errors::ConfigKeyUnset)
      end
    end

    it "raises a usage Error when no key is given" do
      expect {
        described_class.call(args: ["get"], options: {}, output: output)
      }.to raise_error(SlackStatusCli::Cli::Errors::Error, /config get/)
    end

    it "raises a usage Error for a whitespace-only key" do
      expect {
        described_class.call(args: ["get", "   "], options: {}, output: output)
      }.to raise_error(SlackStatusCli::Cli::Errors::Error, /config get/)
    end
  end

  describe ".call(args: ['set', ...])" do
    # Uses the real DottedSet + CoerceScalar (the defaults) so the assertions
    # validate the production config shape: a dotted key writes a nested hash and
    # the value is coerced to its scalar type — not a flat key / raw string.
    it "coerces the value and writes it at the nested dotted key" do
      with_tmp_config do |path:, **|
        SlackStatusCli::Tokens::Commands::WriteConfig.call(config: build_config, path: path)

        described_class.call(args: ["set", "global.timeout", "30"], options: { config_path: path }, output: output)

        loaded = SlackStatusCli::Tokens::Queries::LoadConfig.call(path: path)
        expect(loaded.dig("global", "timeout")).to eq(30)
      end
    end

    it "confirms the set on the output stream" do
      with_tmp_config do |path:, **|
        SlackStatusCli::Tokens::Commands::WriteConfig.call(config: build_config, path: path)

        described_class.call(
          args: ["set", "global.storage_backend", "keychain"],
          options: { config_path: path },
          output: output,
        )

        expect(output.string).to match(/global\.storage_backend/)
      end
    end

    it "echoes the coerced value in the confirmation, not the raw string" do
      with_tmp_config do |path:, **|
        SlackStatusCli::Tokens::Commands::WriteConfig.call(config: build_config, path: path)

        described_class.call(args: ["set", "global.flag", "null"], options: { config_path: path }, output: output)

        expect(output.string).to match(/= nil/)
      end
    end

    it "raises a usage Error when the value is missing" do
      expect {
        described_class.call(args: ["set", "global.timeout"], options: {}, output: output)
      }.to raise_error(SlackStatusCli::Cli::Errors::Error, /config set/)
    end
  end

  describe "help + unknown subcommands" do
    it "prints help for no subcommand" do
      described_class.call(args: [], options: {}, output: output)
      expect(output.string).to match(/config get/).and match(/config set/).and match(/config path/)
    end

    it "prints help for the 'help' subcommand" do
      described_class.call(args: ["help"], options: {}, output: output)
      expect(output.string).to match(/config get/)
    end

    it "raises an Error for an unknown subcommand" do
      expect {
        described_class.call(args: ["frobnicate"], options: {}, output: output)
      }.to raise_error(SlackStatusCli::Cli::Errors::Error, /frobnicate/)
    end
  end
end
