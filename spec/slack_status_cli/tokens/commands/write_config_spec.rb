require "spec_helper"

RSpec.describe SlackStatusCli::Tokens::Commands::WriteConfig do
  describe ".call" do
    it "writes the config so it round-trips through LoadConfig and returns nil" do
      with_tmp_config do |path:, **|
        config = build_config(global: { "storage_backend" => "keychain" })

        result = described_class.call(config: config, path: path)

        expect(result).to be_nil
        expect(SlackStatusCli::Tokens::Queries::LoadConfig.call(path: path)).to eq(config)
      end
    end

    it "creates the parent directory if it is missing" do
      with_tmp_config do |dir:, **|
        path = File.join(dir, "nested", "tree", "config.yml")

        described_class.call(config: build_config, path: path)

        expect(File.exist?(path)).to be(true)
      end
    end

    it "writes with 0600 permissions" do
      with_tmp_config do |path:, **|
        described_class.call(config: build_config, path: path)

        expect(File.stat(path).mode & 0o777).to eq(0o600)
      end
    end

    it "leaves the existing config intact when the rename step fails (atomic)" do
      with_tmp_config do |path:, **|
        File.write(path, "old: data\n")
        allow(File).to receive(:rename).and_raise(Errno::EXDEV)

        expect { described_class.call(config: build_config(global: { "new" => "v" }), path: path) }
          .to raise_error(Errno::EXDEV)

        expect(File.read(path)).to eq("old: data\n")
      end
    end

    it "does not leave a temp file behind after a successful write" do
      with_tmp_config do |dir:, path:|
        described_class.call(config: build_config, path: path)

        leftovers = Dir.children(dir).reject { |name| name == File.basename(path) }
        expect(leftovers).to be_empty
      end
    end
  end
end
