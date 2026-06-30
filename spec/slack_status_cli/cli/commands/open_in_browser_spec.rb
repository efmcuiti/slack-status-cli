require "spec_helper"

RSpec.describe SlackStatusCli::Cli::Commands::OpenInBrowser do
  describe ".call" do
    it "shells out to `open` with the URL on macOS" do
      runner = FakeShellRunner.new.stub(/open/, stdout: "")
      described_class.call(url: "https://slack.test", runner: runner, platform: "x86_64-darwin23")
      expect(runner.calls.first).to eq(["open", "https://slack.test"])
    end

    it "shells out to `xdg-open` on Linux" do
      runner = FakeShellRunner.new.stub(/xdg-open/, stdout: "")
      described_class.call(url: "https://slack.test", runner: runner, platform: "x86_64-linux")
      expect(runner.calls.first).to eq(["xdg-open", "https://slack.test"])
    end

    it "is a no-op when the URL is nil" do
      runner = FakeShellRunner.new
      expect(described_class.call(url: nil, runner: runner)).to be_nil
      expect(runner.calls).to be_empty
    end

    it "passes a URL with spaces as a single argv element (no shell injection)" do
      runner = FakeShellRunner.new.stub(/open/, stdout: "")
      described_class.call(url: "https://slack.test/a b", runner: runner, platform: "x86_64-darwin23")
      expect(runner.calls.first).to eq(["open", "https://slack.test/a b"])
    end
  end
end
