require "spec_helper"
require "stringio"

RSpec.describe SlackStatusCli::Cli::Commands::InstallSignalHandlers do
  # Recording fakes so the spec never registers a real signal trap or at_exit
  # hook — a real at_exit firing ClearStatus would hit the network when rspec
  # itself exits.
  let(:trapper) do
    Class.new do
      attr_reader :traps
      def initialize
        @traps = {}
      end

      def trap(signal, &block)
        @traps[signal] = block
      end
    end.new
  end

  let(:exit_hook) do
    Class.new do
      attr_reader :block
      def at_exit(&block)
        @block = block
      end
    end.new
  end

  let(:clearer) do
    Class.new do
      attr_reader :tokens
      def initialize
        @tokens = []
      end

      def call(token:)
        @tokens << token
      end
    end.new
  end

  let(:terminator) { -> { @terminated = true } }
  let(:output) { StringIO.new }

  def install(token: "xoxp-sig")
    described_class.call(
      token: token,
      trapper: trapper,
      exit_hook: exit_hook,
      clearer: clearer,
      terminator: terminator,
      output: output,
    )
  end

  describe ".call" do
    it "registers handlers for INT and TERM" do
      install
      expect(trapper.traps.keys).to contain_exactly("INT", "TERM")
    end

    it "clears the status on exit after a signal was received" do
      install
      trapper.traps["INT"].call
      exit_hook.block.call
      expect(clearer.tokens).to eq(["xoxp-sig"])
    end

    it "does not clear the status on a normal exit when no signal fired" do
      install
      exit_hook.block.call
      expect(clearer.tokens).to be_empty
    end

    it "does not clear the status when there is no token, even after a signal" do
      install(token: nil)
      trapper.traps["INT"].call
      exit_hook.block.call
      expect(clearer.tokens).to be_empty
    end
  end
end
