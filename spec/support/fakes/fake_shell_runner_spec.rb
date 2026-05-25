require "spec_helper"

RSpec.describe FakeShellRunner do
  subject(:runner) { described_class.new }

  describe "#capture3" do
    it "returns the stubbed tuple when argv matches a regex" do
      runner.stub(/osascript.*current track/, stdout: "Sirens|Cult of Luna|playing")

      stdout, stderr, status = runner.capture3("osascript", "-e", "tell app to get current track")

      expect(stdout).to eq("Sirens|Cult of Luna|playing")
      expect(stderr).to eq("")
      expect(status.success?).to be(true)
    end

    it "returns the stubbed tuple when argv matches a substring" do
      runner.stub("nowplaying-cli get", stdout: "{\"title\":\"Sirens\"}")

      stdout, _stderr, status = runner.capture3("nowplaying-cli", "get", "--json", "title")

      expect(stdout).to eq("{\"title\":\"Sirens\"}")
      expect(status.success?).to be(true)
    end

    it "returns a failing tuple when success: false is stubbed" do
      runner.stub("security find-generic-password", stderr: "item not found", success: false)

      stdout, stderr, status = runner.capture3("security", "find-generic-password", "-s", "slack-status-cli")

      expect(stdout).to eq("")
      expect(stderr).to eq("item not found")
      expect(status.success?).to be(false)
    end

    it "raises when no stub matches the argv (loud failure, not silent)" do
      expect { runner.capture3("dcli", "read", "dl://nope") }
        .to raise_error(FakeShellRunner::UnstubbedCommandError, /dcli read dl:\/\/nope/)
    end

    it "records every call into #calls in argv order" do
      runner.stub("echo", stdout: "hi")

      runner.capture3("echo", "one")
      runner.capture3("echo", "two")

      expect(runner.calls).to eq([
        ["echo", "one"],
        ["echo", "two"]
      ])
    end
  end

  describe "#stub" do
    it "rejects a nil matcher so a typo cannot silently match every command" do
      expect { runner.stub(nil, stdout: "anything") }
        .to raise_error(ArgumentError, /matcher/)
    end

    it "rejects an empty-string matcher so a typo cannot silently match every command" do
      expect { runner.stub("", stdout: "anything") }
        .to raise_error(ArgumentError, /matcher/)
    end
  end
end
