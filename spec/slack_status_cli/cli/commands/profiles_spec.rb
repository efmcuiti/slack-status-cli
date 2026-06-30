require "spec_helper"
require "stringio"

RSpec.describe SlackStatusCli::Cli::Commands::Profiles do
  let(:output) { StringIO.new }

  def write_config(config, path)
    SlackStatusCli::Tokens::Commands::WriteConfig.call(config: config, path: path)
  end

  describe ".call(args: ['list'])" do
    it "reports when no profiles are configured" do
      with_tmp_config do |path:, **|
        write_config(build_config, path)

        described_class.call(args: ["list"], options: { config_path: path }, output: output)

        expect(output.string).to match(/no profiles configured/)
      end
    end

    it "prints every profile with its effective backend" do
      with_tmp_config do |path:, **|
        write_config(
          build_config(
            global: { "storage_backend" => "dashlane" },
            profiles: { "work" => { "storage_backend" => "keychain" }, "personal" => {} },
          ),
          path,
        )

        described_class.call(args: ["list"], options: { config_path: path }, output: output)

        expect(output.string).to match(/Global default backend: dashlane/)
        expect(output.string).to match(/work.*keychain/)
        expect(output.string).to match(/personal.*dashlane/)
      end
    end

    it "defaults to list when no subcommand is given" do
      with_tmp_config do |path:, **|
        write_config(build_config(profiles: { "work" => {} }), path)

        described_class.call(args: [], options: { config_path: path }, output: output)

        expect(output.string).to match(/work/)
      end
    end
  end

  describe ".call(args: ['add', <name>])" do
    it "creates an empty profile entry and writes the config" do
      with_tmp_config do |path:, **|
        write_config(build_config, path)

        described_class.call(args: ["add", "newp"], options: { config_path: path }, output: output)

        loaded = SlackStatusCli::Tokens::Queries::LoadConfig.call(path: path)
        expect(loaded.dig("profiles", "newp")).to eq({})
        expect(output.string).to match(/newp/)
      end
    end

    it "leaves an existing profile's settings intact" do
      with_tmp_config do |path:, **|
        write_config(build_config(profiles: { "work" => { "storage_backend" => "keychain" } }), path)

        described_class.call(args: ["add", "work"], options: { config_path: path }, output: output)

        loaded = SlackStatusCli::Tokens::Queries::LoadConfig.call(path: path)
        expect(loaded.dig("profiles", "work", "storage_backend")).to eq("keychain")
      end
    end

    it "raises a usage Error when no name is given" do
      expect {
        described_class.call(args: ["add"], options: {}, output: output)
      }.to raise_error(SlackStatusCli::Cli::Errors::Error, /profiles add/)
    end
  end

  describe "unknown subcommands" do
    it "raises an Error" do
      with_tmp_config do |path:, **|
        write_config(build_config, path)

        expect {
          described_class.call(args: ["frobnicate"], options: { config_path: path }, output: output)
        }.to raise_error(SlackStatusCli::Cli::Errors::Error, /frobnicate/)
      end
    end
  end
end
