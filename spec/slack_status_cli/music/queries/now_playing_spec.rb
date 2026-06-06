require "spec_helper"
require "json"

RSpec.describe SlackStatusCli::Music::Queries::NowPlaying do
  describe ".call" do
    let(:runner) { FakeShellRunner.new }
    let(:null_track) { SlackStatusCli::Music::Constants::NULL_TRACK }

    def stub_payload(runner, payload, success: true)
      runner.stub("nowplaying-cli", stdout: payload.to_json, success: success)
    end

    it "fetches the now-playing track via nowplaying-cli --json" do
      stub_payload(runner, { "title" => "Sirens", "artist" => "Cult of Luna", "album" => "Vertikal", "playbackRate" => 1 })

      described_class.call(runner: runner)

      expect(runner.calls).to eq(
        [["nowplaying-cli", "get", "--json", "title", "artist", "album", "playbackRate"]]
      )
    end

    it "parses the JSON payload into the tune hash" do
      stub_payload(runner, { "title" => "Sirens", "artist" => "Cult of Luna", "album" => "Vertikal", "playbackRate" => 1 })

      expect(described_class.call(runner: runner)).to eq(
        name: "Sirens", artist: "Cult of Luna", album: "Vertikal", playing: true
      )
    end

    it "treats a playbackRate of 0 as paused" do
      stub_payload(runner, { "title" => "Sirens", "artist" => "Cult of Luna", "album" => "Vertikal", "playbackRate" => 0 })

      expect(described_class.call(runner: runner)).to include(playing: false)
    end

    it "returns NULL_TRACK when nowplaying-cli exits non-zero" do
      runner.stub("nowplaying-cli", stdout: "", stderr: "boom", success: false)

      expect(described_class.call(runner: runner)).to eq(null_track)
    end

    it "returns NULL_TRACK when stdout is empty or unparseable" do
      runner.stub("nowplaying-cli", stdout: "")

      expect(described_class.call(runner: runner)).to eq(null_track)
    end

    it "returns NULL_TRACK when the title is null" do
      stub_payload(runner, { "title" => nil, "artist" => "Cult of Luna", "album" => "Vertikal", "playbackRate" => 1 })

      expect(described_class.call(runner: runner)).to eq(null_track)
    end

    it "returns NULL_TRACK when nowplaying-cli is not installed" do
      missing_runner = Class.new do
        def capture3(*)
          raise Errno::ENOENT, "nowplaying-cli"
        end
      end.new

      expect(described_class.call(runner: missing_runner)).to eq(null_track)
    end
  end
end
