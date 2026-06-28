require "spec_helper"

RSpec.describe SlackStatusCli::EmojiMigration::Commands::WriteSkipped do
  describe ".call" do
    it "writes skipped.json containing the skipped list" do
      with_tmp_config do |dir:, **|
        skipped = [{ "name" => "rocket", "reason" => "HTTP 404" }]

        path = described_class.call(out_dir: dir, skipped: skipped)

        expect(path.to_s).to eq(File.join(dir, "skipped.json"))
        expect(JSON.parse(File.read(path))).to eq([{ "name" => "rocket", "reason" => "HTTP 404" }])
      end
    end

    it "writes an empty JSON array when skipped is empty" do
      with_tmp_config do |dir:, **|
        path = described_class.call(out_dir: dir, skipped: [])

        expect(File.exist?(path)).to be(true)
        expect(JSON.parse(File.read(path))).to eq([])
      end
    end

    it "returns a Pathname" do
      with_tmp_config do |dir:, **|
        path = described_class.call(out_dir: dir, skipped: [])

        expect(path).to be_a(Pathname)
      end
    end
  end
end
