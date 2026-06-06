require "spec_helper"
require "json"

RSpec.describe SlackStatusCli::Music::Queries::CurrentTrack do
  describe ".call" do
    let(:runner) { FakeShellRunner.new }
    let(:null_track) { SlackStatusCli::Music::Constants::NULL_TRACK }

    it "returns the NowPlaying tune when it is non-null" do
      runner.stub(
        "nowplaying-cli",
        stdout: { "title" => "Sirens", "artist" => "Cult of Luna", "album" => "Vertikal", "playbackRate" => 1 }.to_json
      )

      result = described_class.call(runner: runner)

      expect(result).to eq(name: "Sirens", artist: "Cult of Luna", album: "Vertikal", playing: true)
      expect(runner.calls.map(&:first)).to eq(["nowplaying-cli"])
    end

    it "falls back to AppleMusicFallback when NowPlaying returns NULL_TRACK" do
      runner.stub("nowplaying-cli", stdout: "", success: false)
      runner.stub("osascript", stdout: "playing|Embers|Sojourner|Premonitions")

      result = described_class.call(runner: runner)

      expect(result).to eq(name: "Embers", artist: "Sojourner", album: "Premonitions", playing: true)
      expect(runner.calls.map(&:first)).to eq(["nowplaying-cli", "osascript"])
    end

    it "returns NULL_TRACK when both sources are null" do
      runner.stub("nowplaying-cli", stdout: "", success: false)
      runner.stub("osascript", stdout: SlackStatusCli::Music::Constants::NULL_RESPONSE)

      expect(described_class.call(runner: runner)).to eq(null_track)
    end
  end
end
