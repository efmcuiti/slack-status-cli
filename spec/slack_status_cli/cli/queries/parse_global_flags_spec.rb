require "spec_helper"

RSpec.describe SlackStatusCli::Cli::Queries::ParseGlobalFlags do
  describe ".call" do
    it "parses --profile foo into the :profile key" do
      options = described_class.call(argv: ["--profile", "foo"])
      expect(options[:profile]).to eq("foo")
    end

    it "parses --verbose into a true :verbose flag" do
      options = described_class.call(argv: ["--verbose"])
      expect(options[:verbose]).to be(true)
    end

    it "parses -v as an alias for --verbose" do
      options = described_class.call(argv: ["-v"])
      expect(options[:verbose]).to be(true)
    end

    it "parses --dry-run into a true :dry_run flag" do
      options = described_class.call(argv: ["--dry-run"])
      expect(options[:dry_run]).to be(true)
    end

    it "leaves positional args in the mutated argv array" do
      argv = ["setup", "--profile", "foo"]
      described_class.call(argv: argv)
      expect(argv).to eq(["setup"])
    end

    it "returns a Hash carrying the expected keys with defaults" do
      options = described_class.call(argv: [])
      expect(options).to include(
        profile: nil,
        token: nil,
        config_path: nil,
        verbose: false,
        dry_run: false,
        non_interactive: false,
        open_browser: true,
      )
    end
  end
end
