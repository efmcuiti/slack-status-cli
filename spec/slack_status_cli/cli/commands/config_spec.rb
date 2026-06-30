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

  # Records the (hash, key, value) it was handed and mutates the hash like the
  # real DottedSet so the downstream WriteConfig still has something to persist.
  let(:recording_setter) do
    Class.new do
      attr_reader :calls
      def initialize
        @calls = []
      end

      def call(hash:, key:, value:)
        @calls << { hash: hash, key: key, value: value }
        hash[key] = value
        hash
      end
    end.new
  end

  # Records the raw value it was asked to coerce and returns a sentinel so the
  # spec can prove the orchestrator stores the coerced (not raw) value.
  let(:recording_coercer) do
    Class.new do
      attr_reader :calls
      def initialize
        @calls = []
      end

      def call(value:)
        @calls << value
        "COERCED"
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
  end

  describe ".call(args: ['set', ...])" do
    it "coerces the value, delegates to the setter, and writes the config" do
      with_tmp_config do |path:, **|
        SlackStatusCli::Tokens::Commands::WriteConfig.call(config: build_config, path: path)

        described_class.call(
          args: ["set", "global.timeout", "30"],
          options: { config_path: path },
          output: output,
          coercer: recording_coercer,
          setter: recording_setter,
        )

        expect(recording_coercer.calls).to eq(["30"])
        expect(recording_setter.calls.first).to include(key: "global.timeout", value: "COERCED")

        loaded = SlackStatusCli::Tokens::Queries::LoadConfig.call(path: path)
        expect(loaded["global.timeout"]).to eq("COERCED")
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
