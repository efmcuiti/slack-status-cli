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

    it "creates the file with 0600 without a post-write chmod (race-free)" do
      with_tmp_config do |path:, **|
        expect(File).not_to receive(:chmod)

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

    it "does not delete a pre-existing file at the temp path on an O_EXCL collision" do
      with_tmp_config do |dir:, path:|
        command = described_class.new(config: build_config, path: path)
        allow(command).to receive(:rand).and_return(123_456)
        squatted = File.join(dir, ".#{File.basename(path)}.#{Process.pid}.123456.tmp")
        File.write(squatted, "not mine")

        expect { command.call }.to raise_error(Errno::EEXIST)

        expect(File.read(squatted)).to eq("not mine")
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
