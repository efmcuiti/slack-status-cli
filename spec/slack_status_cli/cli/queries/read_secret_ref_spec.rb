require "spec_helper"

RSpec.describe SlackStatusCli::Cli::Queries::ReadSecretRef do
  describe ".call" do
    it "returns the value unchanged when it is not a secret: ref" do
      expect(described_class.call(value: "1234.5678")).to eq("1234.5678")
    end

    it "returns nil for a nil value" do
      expect(described_class.call(value: nil)).to be_nil
    end

    context "for a 'secret:env:VAR' ref" do
      it "returns the value of the named environment variable" do
        expect(described_class.call(value: "secret:env:MY_SECRET", env: { "MY_SECRET" => "xoxp-from-env" }))
          .to eq("xoxp-from-env")
      end

      it "returns nil when the named variable is unset" do
        expect(described_class.call(value: "secret:env:MISSING", env: {})).to be_nil
      end
    end

    context "for a 'secret:dashlane:NAME' ref" do
      it "shells out via the injected runner and returns the trimmed token" do
        runner = FakeShellRunner.new.stub(/dcli read oauth-secret/, stdout: "xoxp-dl\n")
        result = described_class.call(value: "secret:dashlane:oauth-secret", runner: runner)
        expect(result).to eq("xoxp-dl")
        expect(runner.calls.first).to eq(["dcli", "read", "oauth-secret"])
      end

      it "returns nil when the runner reports failure" do
        runner = FakeShellRunner.new.stub(/dcli read/, stdout: "", success: false)
        expect(described_class.call(value: "secret:dashlane:nope", runner: runner)).to be_nil
      end
    end

    context "for a 'secret:keychain:LABEL' ref" do
      it "shells out via the injected runner and returns the trimmed token" do
        runner = FakeShellRunner.new.stub(/security find-generic-password/, stdout: "xoxp-kc\n")
        result = described_class.call(value: "secret:keychain:oauth", runner: runner)
        expect(result).to eq("xoxp-kc")
        expect(runner.calls.first).to eq(["security", "find-generic-password", "-s", "slack-status-cli", "-a", "oauth", "-w"])
      end
    end

    context "for an unknown scheme" do
      it "raises a Cli UnknownSecretScheme error" do
        expect { described_class.call(value: "secret:bogus:x") }
          .to raise_error(SlackStatusCli::Cli::Errors::UnknownSecretScheme, /bogus/)
      end
    end
  end
end
