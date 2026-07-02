require "spec_helper"
require "stringio"

RSpec.describe SlackStatusCli::Cli::Commands::RunStatusMode do
  let(:output) { StringIO.new }

  def resolver_returning(token)
    Class.new do
      define_method(:token) { token }
      def call(profile:, cli_token: nil, config_path: nil, verbose: false)
        { token: token, source: "file", profile: profile }
      end
    end.new
  end

  def resolver_raising(error)
    Class.new do
      define_method(:boom) { error }
      def call(profile:, cli_token: nil, config_path: nil, verbose: false)
        raise boom
      end
    end.new
  end

  let(:recording_updater) do
    Class.new do
      attr_reader :calls
      def initialize
        @calls = []
      end

      def call(token:, mode:, text: nil, emoji: nil, expiration: nil)
        @calls << { token: token, mode: mode, text: text, emoji: emoji, expiration: expiration }
      end
    end.new
  end

  let(:recording_signals) do
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

  def run(command:, args: [], resolver: resolver_returning("xoxp-mode"))
    described_class.call(
      command: command,
      args: args,
      options: {},
      output: output,
      env: {},
      resolver: resolver,
      signal_installer: recording_signals,
      updater: recording_updater,
    )
  end

  describe ".call" do
    it "delegates to UpdateStatus with the resolved token and mode" do
      run(command: "lunch", args: ["Heads down", ":wolf:", "30m"])
      expect(recording_updater.calls.first).to eq(
        token: "xoxp-mode", mode: :lunch, text: "Heads down", emoji: ":wolf:", expiration: "30m",
      )
    end

    it "defaults to the :myth mode when no command is given" do
      run(command: nil)
      expect(recording_updater.calls.first[:mode]).to eq(:myth)
    end

    it "ignores positional args for :musical_myth, passing nil text/emoji/expiration" do
      run(command: "musical_myth", args: ["ignored", "args"])
      expect(recording_updater.calls.first).to include(mode: :musical_myth, text: nil, emoji: nil, expiration: nil)
    end

    it "registers signal handlers with the resolved token" do
      run(command: "myth")
      expect(recording_signals.tokens).to eq(["xoxp-mode"])
    end

    it "treats an unknown mode as a custom freeform status (no error)" do
      run(command: "frobnicate", args: ["Deep in the code"])
      expect(recording_updater.calls.first).to include(mode: :frobnicate, text: "Deep in the code")
    end

    it "raises a Cli error when the token cannot be resolved" do
      resolver = resolver_raising(SlackStatusCli::Tokens::Errors::NotFoundError.new("nothing"))
      expect { run(command: "myth", resolver: resolver) }
        .to raise_error(SlackStatusCli::Cli::Errors::Error, /token/i)
    end
  end
end
