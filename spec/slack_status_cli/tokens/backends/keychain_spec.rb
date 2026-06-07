require "spec_helper"

RSpec.describe SlackStatusCli::Tokens::Backends::Keychain do
  let(:runner) { FakeShellRunner.new }

  def build(profile: "work", settings: {})
    described_class.new(profile: profile, settings: settings, runner: runner)
  end

  def runner_raising(error)
    raiser = Object.new
    raiser.define_singleton_method(:capture3) { |*| raise error }
    raiser
  end

  describe "#read" do
    it "returns the token via `security find-generic-password`" do
      runner.stub(/security find-generic-password/, stdout: "xoxp-keychain\n")

      expect(build.read).to eq("xoxp-keychain")
    end

    it "shells out with the service and account flags" do
      runner.stub(/security/, stdout: "xoxp-x")

      build(profile: "work").read

      expect(runner.calls.last).to eq(
        ["security", "find-generic-password", "-s", "slack-status-cli", "-a", "work", "-w"]
      )
    end

    it "returns nil and records last_error when the item is missing" do
      runner.stub(/security/, stderr: "could not be found", success: false)
      backend = build

      expect(backend.read).to be_nil
      expect(backend.last_error).to eq("could not be found")
    end

    it "returns nil when the captured token is blank" do
      runner.stub(/security/, stdout: "   ")

      expect(build.read).to be_nil
    end

    it "returns nil when the security binary is missing from PATH" do
      backend = described_class.new(profile: "work", runner: runner_raising(Errno::ENOENT))

      expect(backend.read).to be_nil
      expect(backend.last_error).to match(/not found in PATH/)
    end
  end

  describe "#write" do
    it "calls `security add-generic-password` with -U and the token" do
      runner.stub(/security add-generic-password/, success: true)

      build(profile: "work").write("xoxp-new")

      expect(runner.calls.last).to eq(
        ["security", "add-generic-password", "-s", "slack-status-cli", "-a", "work", "-w", "xoxp-new", "-U"]
      )
    end

    it "raises WriteError when security exits non-zero" do
      runner.stub(/security/, stderr: "write denied", success: false)

      expect { build.write("xoxp-new") }
        .to raise_error(SlackStatusCli::Tokens::Errors::WriteError, /write denied/)
    end

    it "falls back to stdout in the WriteError when stderr is blank" do
      runner.stub(/security/, stdout: "errSecDuplicateItem", stderr: "", success: false)

      expect { build.write("xoxp-new") }
        .to raise_error(SlackStatusCli::Tokens::Errors::WriteError, /errSecDuplicateItem/)
    end

    it "raises WriteError when the security binary is missing" do
      backend = described_class.new(profile: "work", runner: runner_raising(Errno::ENOENT))

      expect { backend.write("xoxp-new") }
        .to raise_error(SlackStatusCli::Tokens::Errors::WriteError, /requires macOS/)
    end
  end

  describe "#location" do
    it "defaults to <service>/<account>" do
      expect(build(profile: "work").location).to eq("slack-status-cli/work")
    end

    it "honors service and account overrides from backend_options" do
      settings = { "backend_options" => { "keychain" => { "service" => "svc", "account" => "acct" } } }

      expect(build(settings: settings).location).to eq("svc/acct")
    end
  end

  describe "identity" do
    it "exposes a snake_case name and a humanized source_label" do
      expect(build.name).to eq(:keychain)
      expect(build.source_label).to eq("Keychain")
    end
  end
end
