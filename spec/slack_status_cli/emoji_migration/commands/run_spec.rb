require "spec_helper"

RSpec.describe SlackStatusCli::EmojiMigration::Commands::Run do
  # Real fake collaborator: captures progress lines so the spec can assert the
  # orchestrator narrates its work without coupling to stdout.
  class CapturingLogger
    attr_reader :messages

    def initialize
      @messages = []
    end

    def info(message)
      @messages << message
    end
  end

  def stub_emoji(url, body)
    stub_request(:get, url).to_return(status: 200, body: body)
  end

  describe ".call" do
    context "with concurrency: 1 (deterministic)" do
      it "returns a result struct with downloaded count > 0" do
        with_tmp_config do |dir:, **|
          rocket = "https://emoji.slack-edge.com/T1/rocket/abc.png"
          emoji_map = build_emoji_map(real: { "rocket" => rocket })
          stub_emoji(rocket, "PNGDATA")

          result = described_class.call(emoji_map: emoji_map, out_dir: dir, concurrency: 1)

          expect(result.downloaded.size).to be > 0
          expect(result.downloaded.first[:name]).to eq("rocket")
        end
      end

      it "writes one file per real emoji entry" do
        with_tmp_config do |dir:, **|
          rocket = "https://emoji.slack-edge.com/T1/rocket/abc.png"
          tada = "https://emoji.slack-edge.com/T1/tada/def.gif"
          emoji_map = build_emoji_map(real: { "rocket" => rocket, "tada" => tada })
          stub_emoji(rocket, "PNGDATA")
          stub_emoji(tada, "GIF89aXY")

          described_class.call(emoji_map: emoji_map, out_dir: dir, concurrency: 1)

          expect(File.exist?(File.join(dir, "rocket.png"))).to be(true)
          expect(File.exist?(File.join(dir, "tada.gif"))).to be(true)
        end
      end

      it "writes aliases.json with the alias map" do
        with_tmp_config do |dir:, **|
          rocket = "https://emoji.slack-edge.com/T1/rocket/abc.png"
          emoji_map = build_emoji_map(real: { "rocket" => rocket }, aliases: { "party" => "rocket" })
          stub_emoji(rocket, "PNGDATA")

          result = described_class.call(emoji_map: emoji_map, out_dir: dir, concurrency: 1)

          expect(result.aliases).to eq("party" => "rocket")
          expect(JSON.parse(File.read(File.join(dir, "aliases.json")))).to eq("party" => "rocket")
        end
      end

      it "writes skipped.json with the unparseable names" do
        with_tmp_config do |dir:, **|
          rocket = "https://emoji.slack-edge.com/T1/rocket/abc.png"
          emoji_map = build_emoji_map(real: { "rocket" => rocket }).merge("broken" => "")
          stub_emoji(rocket, "PNGDATA")

          result = described_class.call(emoji_map: emoji_map, out_dir: dir, concurrency: 1)

          written = JSON.parse(File.read(File.join(dir, "skipped.json")))
          expect(written.map { |entry| entry["name"] }).to include("broken")
          expect(result.skipped.map { |entry| entry[:name] }).to include("broken")
        end
      end

      it "sums total_bytes correctly" do
        with_tmp_config do |dir:, **|
          rocket = "https://emoji.slack-edge.com/T1/rocket/abc.png"
          tada = "https://emoji.slack-edge.com/T1/tada/def.gif"
          emoji_map = build_emoji_map(real: { "rocket" => rocket, "tada" => tada })
          stub_emoji(rocket, "PNGDATA")
          stub_emoji(tada, "GIF89aXY")

          result = described_class.call(emoji_map: emoji_map, out_dir: dir, concurrency: 1)

          expect(result.total_bytes).to eq("PNGDATA".bytesize + "GIF89aXY".bytesize)
        end
      end
    end

    it "honors the filter regex" do
      with_tmp_config do |dir:, **|
        rocket = "https://emoji.slack-edge.com/T1/rocket/abc.png"
        tada = "https://emoji.slack-edge.com/T1/tada/def.gif"
        emoji_map = build_emoji_map(real: { "rocket" => rocket, "tada" => tada })
        stub_emoji(rocket, "PNGDATA")

        result = described_class.call(emoji_map: emoji_map, out_dir: dir, filter: "rocket", concurrency: 1)

        expect(result.downloaded.map { |entry| entry[:name] }).to eq(["rocket"])
        expect(File.exist?(File.join(dir, "rocket.png"))).to be(true)
        expect(File.exist?(File.join(dir, "tada.gif"))).to be(false)
      end
    end

    it "calls logger.info with progress when logger: is provided" do
      with_tmp_config do |dir:, **|
        rocket = "https://emoji.slack-edge.com/T1/rocket/abc.png"
        emoji_map = build_emoji_map(real: { "rocket" => rocket })
        stub_emoji(rocket, "PNGDATA")
        logger = CapturingLogger.new

        described_class.call(emoji_map: emoji_map, out_dir: dir, logger: logger, concurrency: 1)

        expect(logger.messages).not_to be_empty
        expect(logger.messages).to include(a_string_matching(/rocket/))
      end
    end

    context "telemetry" do
      it "emits a start event with the entry counts" do
        with_tmp_config do |dir:, **|
          rocket = "https://emoji.slack-edge.com/T1/rocket/abc.png"
          emoji_map = build_emoji_map(real: { "rocket" => rocket }, aliases: { "party" => "rocket" })
          stub_emoji(rocket, "PNGDATA")
          telemetry = CapturingTelemetry.new

          described_class.call(emoji_map: emoji_map, out_dir: dir, telemetry: telemetry, concurrency: 1)

          expect(telemetry.entry_for("emoji export started").tags).to include(images: 1, aliases: 1, unparseable: 0)
        end
      end

      it "emits a downloaded event per image with name, extension, and bytes" do
        with_tmp_config do |dir:, **|
          rocket = "https://emoji.slack-edge.com/T1/rocket/abc.png"
          emoji_map = build_emoji_map(real: { "rocket" => rocket })
          stub_emoji(rocket, "PNGDATA")
          telemetry = CapturingTelemetry.new

          described_class.call(emoji_map: emoji_map, out_dir: dir, telemetry: telemetry, concurrency: 1)

          entry = telemetry.entry_for("emoji downloaded")
          expect(entry.tags).to include(name: "rocket", extension: "png", bytes: "PNGDATA".bytesize)
        end
      end

      it "emits a warn skipped event with name and reason on a download failure" do
        with_tmp_config do |dir:, **|
          boom = "https://emoji.slack-edge.com/T1/boom/x.png"
          emoji_map = build_emoji_map(real: { "boom" => boom })
          stub_request(:get, boom).to_return(status: 500)
          telemetry = CapturingTelemetry.new

          described_class.call(emoji_map: emoji_map, out_dir: dir, telemetry: telemetry, concurrency: 1)

          entry = telemetry.entry_for("emoji skipped")
          expect(entry.level).to eq(:warn)
          expect(entry.tags[:name]).to eq("boom")
          expect(entry.tags[:reason]).to be_a(String)
        end
      end

      it "emits a finish event with the totals" do
        with_tmp_config do |dir:, **|
          rocket = "https://emoji.slack-edge.com/T1/rocket/abc.png"
          emoji_map = build_emoji_map(real: { "rocket" => rocket })
          stub_emoji(rocket, "PNGDATA")
          telemetry = CapturingTelemetry.new

          described_class.call(emoji_map: emoji_map, out_dir: dir, telemetry: telemetry, concurrency: 1)

          expect(telemetry.entry_for("emoji export finished").tags)
            .to include(downloaded: 1, total_bytes: "PNGDATA".bytesize)
        end
      end

      it "stays silent by default (NullLogger) without a telemetry: argument" do
        with_tmp_config do |dir:, **|
          rocket = "https://emoji.slack-edge.com/T1/rocket/abc.png"
          emoji_map = build_emoji_map(real: { "rocket" => rocket })
          stub_emoji(rocket, "PNGDATA")

          expect { described_class.call(emoji_map: emoji_map, out_dir: dir, concurrency: 1) }.not_to raise_error
        end
      end
    end
  end
end
