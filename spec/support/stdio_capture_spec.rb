require "spec_helper"

RSpec.describe StdioCapture do
  let(:host) { Class.new { include StdioCapture }.new }

  describe "#capture_stdio" do
    it "returns stdout written inside the block" do
      result = host.capture_stdio { puts "hello-out" }

      expect(result[:stdout]).to eq("hello-out\n")
    end

    it "returns stderr written inside the block" do
      result = host.capture_stdio { warn("hello-err") }

      expect(result[:stderr]).to eq("hello-err\n")
    end

    it "restores $stdout and $stderr after the block" do
      original_stdout = $stdout
      original_stderr = $stderr

      host.capture_stdio { puts "ignored" }

      expect($stdout).to be(original_stdout)
      expect($stderr).to be(original_stderr)
    end

    it "restores $stdout and $stderr even when the block raises" do
      original_stdout = $stdout
      original_stderr = $stderr

      expect { host.capture_stdio { raise("boom") } }.to raise_error("boom")

      expect($stdout).to be(original_stdout)
      expect($stderr).to be(original_stderr)
    end
  end
end
