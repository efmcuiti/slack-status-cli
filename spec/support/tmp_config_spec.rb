require "spec_helper"

RSpec.describe TmpConfig do
  let(:host) { Class.new { include TmpConfig }.new }

  describe "#with_tmp_config" do
    it "yields a writable path inside a tempdir" do
      captured = nil

      host.with_tmp_config do |path:, dir:|
        captured = { path: path, dir: dir }
        File.write(path, "key: value\n")
        expect(File.read(path)).to eq("key: value\n")
      end

      expect(captured[:path]).to eq(File.join(captured[:dir], "config.yml"))
      expect(captured[:dir]).to match(%r{slack-status-cli-config})
    end

    it "cleans up the tempdir on success" do
      leaked_dir = nil

      host.with_tmp_config do |path:, dir:|
        leaked_dir = dir
        File.write(path, "anything")
      end

      expect(File.exist?(leaked_dir)).to be(false)
    end

    it "cleans up the tempdir on exception" do
      leaked_dir = nil

      expect do
        host.with_tmp_config do |path:, dir:|
          leaked_dir = dir
          File.write(path, "anything")
          raise("boom")
        end
      end.to raise_error("boom")

      expect(File.exist?(leaked_dir)).to be(false)
    end
  end
end
