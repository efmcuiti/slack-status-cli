require "spec_helper"
require "stringio"

RSpec.describe SlackStatusCli::Slack::Commands::TickMusicalStatus do
  describe ".call" do
    let(:token) { "xoxp-test-token-1234" }
    let(:output) { StringIO.new }
    let(:set_status) { SlackStatusCli::Slack::Commands::SetStatus }

    def raw_tune(name: "Sirens", artist: "Cult of Luna", album: "Vertikal", playing: true)
      { name: name, artist: artist, album: album, playing: playing }
    end

    it "calls SetStatus with the formatted now-playing text and the music emoji" do
      expect(set_status).to receive(:call).with(
        token: token,
        text: a_string_including("Sirens"),
        emoji: ":music:",
        expiration: nil,
        output: output
      )

      described_class.call(token: token, current_track: -> { raw_tune }, output: output)
    end

    it "returns the enriched tune (raw tune plus derived state) for the caller" do
      allow(set_status).to receive(:call)

      result = described_class.call(token: token, current_track: -> { raw_tune }, output: output)

      expect(result).to eq(state: :playing, name: "Sirens", artist: "Cult of Luna", album: "Vertikal")
    end

    it "skips SetStatus and reports :silent when nothing is playing" do
      silent = raw_tune(name: nil, artist: nil, album: nil, playing: false)
      expect(set_status).not_to receive(:call)

      result = described_class.call(token: token, current_track: -> { silent }, output: output)

      expect(result[:state]).to eq(:silent)
    end
  end
end
