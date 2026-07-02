require "spec_helper"
require "stringio"

RSpec.describe SlackStatusCli::Cli::Commands::Setup do
  let(:output) { StringIO.new }

  # Minimal prompt double: returns canned answers for ask/ask_yes_no and records
  # what was asked. Cosmetic helpers (step/done/info/...) are no-ops here because
  # the orchestrator routes assertable progress through `output` instead.
  let(:prompt) do
    Class.new do
      attr_reader :asks, :secret_asks, :yes_no_asks
      attr_accessor :ask_answer, :secret_answer, :yes_no_answer

      def initialize
        @asks = []
        @secret_asks = []
        @yes_no_asks = []
        @ask_answer = "typed-client-id"
        @secret_answer = "typed-secret"
        @yes_no_answer = true
      end

      def ask(question, default: nil, secret: false, input: nil, output: nil, non_interactive: false)
        if secret
          @secret_asks << question
          @secret_answer
        else
          @asks << question
          @ask_answer
        end
      end

      def ask_yes_no(question, default: :yes, input: nil, output: nil, non_interactive: false)
        @yes_no_asks << question
        @yes_no_answer
      end
    end.new
  end

  let(:config_loader) do
    cfg = config
    Class.new do
      define_method(:config) { cfg }
      def call(path:)
        config
      end
    end.new
  end
  let(:config) { build_config }

  let(:config_writer) do
    Class.new do
      attr_reader :writes
      def initialize
        @writes = []
      end

      def call(config:, path:)
        @writes << { config: config, path: path }
        nil
      end
    end.new
  end

  def resolver_returning(value)
    Class.new do
      define_method(:value) { value }
      def call(config:, profile:)
        value
      end
    end.new
  end

  def backend_returning(sym)
    Class.new do
      define_method(:sym) { sym }
      def call(config:, profile:)
        sym
      end
    end.new
  end

  def checker_returning(bool)
    Class.new do
      define_method(:bool) { bool }
      def call(profile:, config_path:)
        bool
      end
    end.new
  end

  let(:recording_oauth) do
    Class.new do
      attr_reader :calls
      def initialize
        @calls = []
      end

      def call(client_id:, client_secret:, scopes:, port:, timeout:)
        @calls << { client_id: client_id, client_secret: client_secret }
        yield(authorize_url: "https://slack.com/oauth/v2/authorize?x", redirect_uri: "http://localhost:53682/callback") if block_given?
        { token: "xoxp-new-token", scope: "users.profile:write", team_name: "Phoenix HQ" }
      end
    end.new
  end

  let(:recording_persister) do
    Class.new do
      attr_reader :calls
      def initialize
        @calls = []
      end

      def call(profile:, token:, backend_name:, settings:)
        @calls << { profile: profile, token: token, backend_name: backend_name }
        { source: "file", location: "/tmp/tokens/#{profile}" }
      end
    end.new
  end

  let(:recording_global) do
    Class.new do
      attr_reader :calls
      def initialize
        @calls = []
      end

      def call(defaults:, config_path:)
        @calls << { defaults: defaults, config_path: config_path }
        nil
      end
    end.new
  end

  let(:noop_browser) do
    Class.new do
      attr_reader :urls
      def initialize
        @urls = []
      end

      def call(url:)
        @urls << url
      end
    end.new
  end

  let(:noop_instructions) do
    Class.new do
      attr_reader :printed
      def initialize
        @printed = 0
      end

      def call(output: nil)
        @printed += 1
      end
    end.new
  end

  def run(options: {}, client_id: "cfg-cid", client_secret: "cfg-secret", backend: :file, has_token: false, oauth: recording_oauth, persister: recording_persister, global: recording_global, prompt_obj: prompt)
    described_class.call(
      options: options,
      output: output,
      env: {},
      prompt: prompt_obj,
      config_loader: config_loader,
      config_writer: config_writer,
      client_id_resolver: resolver_returning(client_id),
      client_secret_resolver: resolver_returning(client_secret),
      backend_resolver: backend_returning(backend),
      token_checker: checker_returning(has_token),
      instructions: noop_instructions,
      oauth_installer: oauth,
      browser: noop_browser,
      token_persister: persister,
      global_persister: global,
    )
  end

  describe ".call (interactive profile install)" do
    it "calls the oauth installer with the resolved client_id and secret" do
      run
      expect(recording_oauth.calls.first).to eq(client_id: "cfg-cid", client_secret: "cfg-secret")
    end

    it "persists the returned token through the token persister" do
      run
      expect(recording_persister.calls.first).to include(token: "xoxp-new-token", backend_name: "file")
    end

    it "opens the authorize URL in the browser during the flow" do
      run
      expect(noop_browser.urls).to eq(["https://slack.com/oauth/v2/authorize?x"])
    end

    it "writes a completion line to output" do
      run
      expect(output.string).to match(/Setup complete/)
    end
  end

  describe "prompting for missing credentials" do
    it "prints the app-creation instructions and prompts when client_id is unresolved" do
      run(client_id: nil)
      expect(noop_instructions.printed).to eq(1)
      expect(prompt.asks).not_to be_empty
      expect(recording_oauth.calls.first[:client_id]).to eq("typed-client-id")
    end

    it "prompts (hidden) when client_secret is unresolved" do
      run(client_secret: nil)
      expect(prompt.secret_asks).not_to be_empty
      expect(recording_oauth.calls.first[:client_secret]).to eq("typed-secret")
    end
  end

  describe "--global" do
    it "persists the global defaults and skips the oauth flow" do
      run(options: { global: true })
      expect(recording_global.calls.first[:defaults]).to include("storage_backend" => "file")
      expect(recording_oauth.calls).to be_empty
      expect(output.string).to match(/Setup complete/)
    end
  end

  describe "overwrite guard" do
    it "skips the oauth flow when an existing token is kept" do
      prompt.yes_no_answer = false
      run(has_token: true, options: {})
      expect(recording_oauth.calls).to be_empty
      expect(output.string).to match(/Keeping existing token/)
    end

    it "proceeds when --rotate is set, without asking" do
      run(has_token: true, options: { rotate: true })
      expect(prompt.yes_no_asks).to be_empty
      expect(recording_oauth.calls).not_to be_empty
    end
  end

  describe "manual-write backends" do
    it "prints the ManualWriteRequired token line verbatim, with no leading indent" do
      persister = Class.new do
        def call(profile:, token:, backend_name:, settings:)
          raise SlackStatusCli::Tokens::Errors::ManualWriteRequired,
                "Paste the token below:\nxoxp-manual-token"
        end
      end.new

      run(persister: persister)

      expect(output.string).to include("\nxoxp-manual-token")
      expect(output.string).not_to match(/^\s+xoxp-manual-token/)
    end
  end

  describe "missing input in non-interactive mode" do
    # Mimics the real CliPrompt, which raises ArgumentError when asked to prompt
    # in non-interactive mode. Setup must guard BEFORE calling ask, so this
    # exploder proves it never prompts and surfaces a Cli::Errors::Error instead.
    let(:exploding_prompt) do
      Class.new do
        def ask(*)
          raise ArgumentError, "must not prompt in non-interactive mode"
        end

        def ask_yes_no(*)
          true
        end
      end.new
    end

    it "raises a clear Cli error (not ArgumentError) without prompting for a missing client_id" do
      expect { run(client_id: nil, options: { non_interactive: true }, prompt_obj: exploding_prompt) }
        .to raise_error(SlackStatusCli::Cli::Errors::Error, /[Cc]lient ID/)
    end

    it "raises a clear Cli error (not ArgumentError) without prompting for a missing client_secret" do
      expect { run(client_secret: nil, options: { non_interactive: true }, prompt_obj: exploding_prompt) }
        .to raise_error(SlackStatusCli::Cli::Errors::Error, /[Cc]lient [Ss]ecret/)
    end
  end
end
