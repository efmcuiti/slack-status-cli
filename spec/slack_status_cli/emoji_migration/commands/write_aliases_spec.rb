require "spec_helper"

RSpec.describe SlackStatusCli::EmojiMigration::Commands::WriteAliases do
  describe ".call" do
    it "writes aliases.json containing the alias map" do
      with_tmp_config do |dir:, **|
        aliases = { "phoenix_alias" => "phoenix_ash" }

        path = described_class.call(out_dir: dir, aliases: aliases)

        expect(path.to_s).to eq(File.join(dir, "aliases.json"))
        expect(JSON.parse(File.read(path))).to eq("phoenix_alias" => "phoenix_ash")
      end
    end

    it "returns a Pathname" do
      with_tmp_config do |dir:, **|
        path = described_class.call(out_dir: dir, aliases: {})

        expect(path).to be_a(Pathname)
      end
    end

    it "creates out_dir when it does not exist yet" do
      with_tmp_config do |dir:, **|
        nested = File.join(dir, "nested", "emoji")

        path = described_class.call(out_dir: nested, aliases: { "a" => "b" })

        expect(File.exist?(path)).to be(true)
      end
    end

    it "overwrites idempotently when re-run with the same content" do
      with_tmp_config do |dir:, **|
        described_class.call(out_dir: dir, aliases: { "a" => "b" })
        path = described_class.call(out_dir: dir, aliases: { "a" => "b" })

        expect(JSON.parse(File.read(path))).to eq("a" => "b")
      end
    end
  end
end
