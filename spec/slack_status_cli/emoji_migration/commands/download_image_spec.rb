require "spec_helper"

RSpec.describe SlackStatusCli::EmojiMigration::Commands::DownloadImage do
  describe ".call" do
    it "GETs the URL and writes the body to out_dir/<sanitized_name>.<ext>" do
      with_tmp_config do |dir:, **|
        url = "https://emoji.slack-edge.com/T1/rocket/abc.png"
        stub_request(:get, url).to_return(status: 200, body: "PNGDATA")

        result = described_class.call(name: "rocket", url: url, out_dir: dir)

        written = File.join(dir, "rocket.png")
        expect(File.exist?(written)).to be(true)
        expect(File.binread(written)).to eq("PNGDATA")
        expect(result[:path]).to eq(written)
      end
    end

    it "returns { name:, path:, bytes:, extension: }" do
      with_tmp_config do |dir:, **|
        url = "https://emoji.slack-edge.com/T1/rocket/abc.gif"
        stub_request(:get, url).to_return(status: 200, body: "GIF89aDATA")

        result = described_class.call(name: "rocket", url: url, out_dir: dir)

        expect(result).to eq(
          name: "rocket",
          path: File.join(dir, "rocket.gif"),
          bytes: "GIF89aDATA".bytesize,
          extension: "gif"
        )
      end
    end

    it "creates out_dir when it does not exist yet" do
      with_tmp_config do |dir:, **|
        nested = File.join(dir, "nested", "emoji")
        url = "https://emoji.slack-edge.com/T1/rocket/abc.png"
        stub_request(:get, url).to_return(status: 200, body: "PNGDATA")

        described_class.call(name: "rocket", url: url, out_dir: nested)

        expect(File.exist?(File.join(nested, "rocket.png"))).to be(true)
      end
    end

    it "raises on an HTTP failure response" do
      with_tmp_config do |dir:, **|
        url = "https://emoji.slack-edge.com/T1/rocket/abc.png"
        stub_request(:get, url).to_return(status: 404, body: "nope")

        expect { described_class.call(name: "rocket", url: url, out_dir: dir) }
          .to raise_error(/HTTP 404/)
      end
    end

    it "sniffs the extension via ExtensionFor when the URL has no suffix" do
      with_tmp_config do |dir:, **|
        url = "https://emoji.slack-edge.com/T1/rocket/blob"
        stub_request(:get, url).to_return(status: 200, body: "\x89PNG\r\n\x1a\n")

        result = described_class.call(name: "rocket", url: url, out_dir: dir)

        expect(result[:extension]).to eq("png")
        expect(File.exist?(File.join(dir, "rocket.png"))).to be(true)
      end
    end

    it "sanitizes the name via SanitizeFilename" do
      with_tmp_config do |dir:, **|
        url = "https://emoji.slack-edge.com/T1/weird/abc.png"
        stub_request(:get, url).to_return(status: 200, body: "PNGDATA")

        result = described_class.call(name: "weird:name", url: url, out_dir: dir)

        expect(result[:name]).to eq("weird:name")
        expect(File.basename(result[:path])).to eq("weird_name.png")
      end
    end
  end
end
