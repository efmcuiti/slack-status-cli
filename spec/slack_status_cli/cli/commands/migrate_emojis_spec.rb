require "spec_helper"
require "stringio"

RSpec.describe SlackStatusCli::Cli::Commands::MigrateEmojis do
  let(:output) { StringIO.new }

  def resolver_returning(token)
    Class.new do
      define_method(:token) { token }
      def call(profile:, cli_token: nil, config_path: nil, verbose: false)
        { token: token, source: "file", profile: profile }
      end
    end.new
  end

  # EmojiList fake: records the token it was called with, returns a canned body.
  let(:recording_emoji_list) do
    Class.new do
      attr_reader :tokens, :response
      def initialize
        @tokens = []
      end

      def stub(resp)
        @response = resp
        self
      end

      def call(token:)
        @tokens << token
        @response
      end
    end.new
  end

  # Run fake: records the emoji_map + telemetry it was handed, returns a Result.
  let(:recording_migrator) do
    Class.new do
      attr_reader :maps, :telemetries, :result
      def initialize
        @maps = []
        @telemetries = []
        @result = SlackStatusCli::EmojiMigration::Commands::Run::Result.new(
          [{ name: "rocket", bytes: 2048 }], { "party" => "rocket" }, [], 2048,
        )
      end

      def call(emoji_map:, out_dir:, filter: nil, telemetry: nil)
        @maps << emoji_map
        @telemetries << telemetry
        @result
      end
    end.new
  end

  def run(options:, resolver: resolver_returning("xoxp-from"), emoji_list: recording_emoji_list, migrator: recording_migrator, **rest)
    emoji_list.stub("ok" => true, "emoji" => { "rocket" => "https://e/rocket.png" }) if emoji_list.response.nil?
    described_class.call(
      options: options,
      output: output,
      resolver: resolver,
      emoji_list: emoji_list,
      migrator: migrator,
      **rest,
    )
  end

  describe ".call" do
    it "fetches emoji.list with the resolved source token" do
      run(options: { from: "work", out: "/tmp/out" })
      expect(recording_emoji_list.tokens).to eq(["xoxp-from"])
    end

    it "delegates to Run with the fetched emoji map" do
      recording_emoji_list.stub("ok" => true, "emoji" => { "rocket" => "https://e/rocket.png", "tada" => "https://e/tada.gif" })
      run(options: { from: "work", out: "/tmp/out" }, emoji_list: recording_emoji_list)
      expect(recording_migrator.maps.first).to eq("rocket" => "https://e/rocket.png", "tada" => "https://e/tada.gif")
    end

    it "threads the injected telemetry into Run (composition-root wiring)" do
      telemetry = CapturingTelemetry.new
      run(options: { from: "work", out: "/tmp/out" }, telemetry: telemetry)
      expect(recording_migrator.telemetries).to eq([telemetry])
    end

    it "defaults telemetry to a resolved logger when none is injected" do
      run(options: { from: "work", out: "/tmp/out" })
      expect(recording_migrator.telemetries.first).to respond_to(:rich_log)
    end

    it "prints the result struct summary" do
      run(options: { from: "work", out: "/tmp/out" })
      expect(output.string).to match(/1 image/)
      expect(output.string).to match(/1 alias/)
    end

    it "raises a usage Error when --from is missing" do
      expect { run(options: {}) }
        .to raise_error(SlackStatusCli::Cli::Errors::Error, /--from/)
    end

    it "raises a usage Error when --from is whitespace only" do
      expect { run(options: { from: "   " }) }
        .to raise_error(SlackStatusCli::Cli::Errors::Error, /--from/)
    end

    it "raises a clear error when the token lacks the emoji:read scope" do
      recording_emoji_list.stub("ok" => false, "error" => "missing_scope")
      expect { run(options: { from: "work" }, emoji_list: recording_emoji_list) }
        .to raise_error(SlackStatusCli::Cli::Errors::Error, /emoji:read/)
    end

    it "opens the destination admin URL when --to resolves and browsing is enabled" do
      browser = Class.new do
        attr_reader :urls
        def initialize
          @urls = []
        end

        def call(url:)
          @urls << url
        end
      end.new
      auth_test = Class.new do
        def call(token:)
          { "ok" => true, "url" => "https://dest.slack.com/" }
        end
      end.new

      run(
        options: { from: "work", to: "dest", out: "/tmp/out", open_browser: true },
        auth_test: auth_test,
        browser: browser,
      )

      expect(browser.urls).to eq(["https://dest.slack.com/customize/emoji"])
    end
  end
end
