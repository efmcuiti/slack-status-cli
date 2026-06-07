require "spec_helper"

RSpec.describe SlackStatusCli::Tokens::Backends::Dashlane do
  let(:runner) { FakeShellRunner.new }

  def build(profile: "work", settings: {})
    described_class.new(profile: profile, settings: settings, runner: runner)
  end

  describe "#read" do
    it "returns the Secure Note content via `dcli note --output json`" do
      runner.stub(/dcli note --output json/, stdout: %([{"content":"xoxp-from-vault"}]))

      expect(build.read).to eq("xoxp-from-vault")
    end

    it "shells out with the profile-derived note title" do
      runner.stub(/dcli note/, stdout: %([{"content":"xoxp-x"}]))

      build(profile: "work").read

      expect(runner.calls.last).to eq(
        ["dcli", "note", "--output", "json", "title=slack-status-cli/work-token"]
      )
    end

    it "returns nil and records an ANSI-stripped last_error when dcli exits non-zero" do
      runner.stub(/dcli note/, stderr: "\e[31mvault locked\e[0m", success: false)
      backend = build

      expect(backend.read).to be_nil
      expect(backend.last_error).to eq("vault locked")
    end

    it "returns nil when dcli emits non-JSON output" do
      runner.stub(/dcli note/, stdout: "not json at all")
      backend = build

      expect(backend.read).to be_nil
      expect(backend.last_error).to match(/non-JSON/)
    end

    it "returns nil when no Secure Note matches the title" do
      runner.stub(/dcli note/, stdout: "[]")
      backend = build

      expect(backend.read).to be_nil
      expect(backend.last_error).to match(/no Secure Note matches/)
    end

    it "returns nil when the matched note has empty content" do
      runner.stub(/dcli note/, stdout: %([{"content":"   "}]))
      backend = build

      expect(backend.read).to be_nil
      expect(backend.last_error).to match(/content is empty/)
    end

    it "returns nil when the dcli binary is missing from PATH" do
      missing = Object.new
      def missing.capture3(*)
        raise Errno::ENOENT
      end
      backend = described_class.new(profile: "work", runner: missing)

      expect(backend.read).to be_nil
      expect(backend.last_error).to match(/not found in PATH/)
    end
  end

  describe "#write" do
    it "raises ManualWriteRequired without shelling out (no unattended Dashlane write)" do
      backend = build

      expect { backend.write("xoxp-secret") }
        .to raise_error(SlackStatusCli::Tokens::Errors::ManualWriteRequired, /xoxp-secret/)
      expect(runner.calls).to be_empty
    end

    it "names the exact Secure Note title in the instructions" do
      expect { build(profile: "work").write("t") }
        .to raise_error(
          SlackStatusCli::Tokens::Errors::ManualWriteRequired,
          %r{slack-status-cli/work-token}
        )
    end
  end

  describe "#location / token_ref" do
    it "defaults to dl://slack-status-cli/<profile>-token" do
      expect(build(profile: "work").location).to eq("dl://slack-status-cli/work-token")
    end

    it "honors an explicit token_ref from settings" do
      expect(build(settings: { "token_ref" => "dl://custom/ref" }).location).to eq("dl://custom/ref")
    end

    it "honors a custom title_prefix from backend_options" do
      settings = { "backend_options" => { "dashlane" => { "title_prefix" => "team-vault" } } }

      expect(build(profile: "work", settings: settings).location).to eq("dl://team-vault/work-token")
    end
  end

  describe "identity" do
    it "exposes a snake_case name and a humanized source_label" do
      expect(build.name).to eq(:dashlane)
      expect(build.source_label).to eq("Dashlane")
    end
  end
end
