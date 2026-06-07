require "spec_helper"

RSpec.describe SlackStatusCli::Tokens::Backends::File do
  def build(path:, profile: "default")
    settings = { "backend_options" => { "file" => { "path" => path } } }
    described_class.new(profile: profile, settings: settings)
  end

  describe "#read" do
    it "returns the token when the file exists with 0600 perms" do
      with_tmp_config do |dir:, **|
        path = File.join(dir, "default.token")
        File.write(path, "xoxp-on-disk\n")
        File.chmod(0o600, path)

        expect(build(path: path).read).to eq("xoxp-on-disk")
      end
    end

    it "returns nil and records last_error when the file is missing" do
      with_tmp_config do |dir:, **|
        backend = build(path: File.join(dir, "absent.token"))

        expect(backend.read).to be_nil
        expect(backend.last_error).to eq("file does not exist")
      end
    end

    it "warns and returns nil when permissions are looser than 0600" do
      with_tmp_config do |dir:, **|
        path = File.join(dir, "default.token")
        File.write(path, "xoxp-leaky\n")
        File.chmod(0o644, path)
        backend = build(path: path)

        result = nil
        captured = capture_stdio { result = backend.read }

        expect(result).to be_nil
        expect(backend.last_error).to eq("permissions too open")
        expect(captured[:stderr]).to match(/permissions .* too open/)
      end
    end

    it "returns nil when the file is present but empty" do
      with_tmp_config do |dir:, **|
        path = File.join(dir, "default.token")
        File.write(path, "   \n")
        File.chmod(0o600, path)

        expect(build(path: path).read).to be_nil
      end
    end
  end

  describe "#write" do
    it "writes the token to the path with a trailing newline and 0600 perms" do
      with_tmp_config do |dir:, **|
        path = File.join(dir, "default.token")
        build(path: path).write("xoxp-new")

        expect(File.read(path)).to eq("xoxp-new\n")
        expect(File.stat(path).mode & 0o777).to eq(0o600)
      end
    end

    it "creates the parent directory if it is missing" do
      with_tmp_config do |dir:, **|
        path = File.join(dir, "nested", "tree", "default.token")
        build(path: path).write("xoxp-new")

        expect(File.exist?(path)).to be(true)
      end
    end
  end

  describe "#location" do
    it "returns the configured path" do
      expect(build(path: "/tmp/custom.token").location).to eq("/tmp/custom.token")
    end

    it "defaults to ~/.config/slack-status-cli/tokens/<profile> when unset" do
      backend = described_class.new(profile: "work")

      expect(backend.location).to eq(File.expand_path("~/.config/slack-status-cli/tokens/work"))
    end
  end

  describe "identity" do
    it "exposes a snake_case name and a humanized source_label" do
      expect(build(path: "/tmp/x").name).to eq(:file)
      expect(build(path: "/tmp/x").source_label).to eq("File")
    end
  end
end
