require "spec_helper"

RSpec.describe SlackStatusCli::Music::Queries::AppleMusicFallback do
  describe ".call" do
    let(:runner) { FakeShellRunner.new }
    let(:script) { SlackStatusCli::Music::Constants::SAFE_MUSIC_SCRIPT }
    let(:null_track) { SlackStatusCli::Music::Constants::NULL_TRACK }

    it "runs SAFE_MUSIC_SCRIPT via osascript" do
      runner.stub("osascript", stdout: "playing|Sirens|Cult of Luna|Vertikal")

      described_class.call(runner: runner)

      expect(runner.calls).to eq([["osascript", "-e", script]])
    end

    it "parses the pipe-delimited output into the tune hash" do
      runner.stub("osascript", stdout: "playing|Sirens|Cult of Luna|Vertikal")

      expect(described_class.call(runner: runner)).to eq(
        name: "Sirens", artist: "Cult of Luna", album: "Vertikal", playing: true
      )
    end

    it "marks the tune paused when the player state is not playing" do
      runner.stub("osascript", stdout: "paused|Sirens|Cult of Luna|Vertikal")

      expect(described_class.call(runner: runner)).to include(playing: false)
    end

    it "returns NULL_TRACK when osascript exits non-zero" do
      runner.stub("osascript", stdout: "", stderr: "boom", success: false)

      expect(described_class.call(runner: runner)).to eq(null_track)
    end

    it "returns NULL_TRACK when the script reports nothing playing" do
      runner.stub("osascript", stdout: SlackStatusCli::Music::Constants::NULL_RESPONSE)

      expect(described_class.call(runner: runner)).to eq(null_track)
    end
  end
end
