require "spec_helper"
require "stringio"

RSpec.describe SlackStatusCli::Cli::Commands::Doctor do
  let(:output) { StringIO.new }

  # Resolver fake mirroring Tokens::Queries::ResolveToken's success shape.
  def resolver_returning(info)
    Class.new do
      define_method(:result) { info }
      def call(profile:, cli_token: nil, config_path: nil, verbose: false)
        result
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

  # AuthTest fake that records the token it was called with and returns a
  # canned response (or raises).
  let(:recording_auth_test) do
    Class.new do
      attr_reader :tokens, :response, :error
      def initialize
        @tokens = []
      end

      def stub_response(resp)
        @response = resp
        self
      end

      def stub_error(err)
        @error = err
        self
      end

      def call(token:)
        @tokens << token
        raise @error if @error

        @response
      end
    end.new
  end

  def run(resolver:, auth_test: recording_auth_test, options: {})
    described_class.call(
      options: options,
      output: output,
      resolver: resolver,
      auth_test: auth_test,
      env: {},
    )
  end

  describe ".call" do
    it "reports the resolved source and calls AuthTest with the resolved token" do
      info = { token: "xoxp-good", source: "file", profile: "default" }
      recording_auth_test.stub_response(build_slack_auth_response(team: "Phoenix HQ", user: "efmcuiti"))

      run(resolver: resolver_returning(info), auth_test: recording_auth_test)

      expect(recording_auth_test.tokens).to eq(["xoxp-good"])
      expect(output.string).to match(/source\s*:\s*file/)
    end

    it "prints the team + user info on success" do
      info = { token: "xoxp-good", source: "file", profile: "default" }
      recording_auth_test.stub_response(build_slack_auth_response(team: "Phoenix HQ", user: "efmcuiti"))

      run(resolver: resolver_returning(info), auth_test: recording_auth_test)

      expect(output.string).to match(/Phoenix HQ/)
      expect(output.string).to match(/efmcuiti/)
    end

    it "raises a Cli error when the resolver cannot find a token" do
      resolver = resolver_raising(SlackStatusCli::Tokens::Errors::NotFoundError.new("nothing here"))

      expect { run(resolver: resolver) }
        .to raise_error(SlackStatusCli::Cli::Errors::Error, /token/i)
    end

    it "prints the DoctorHint and raises when Slack rejects the token" do
      info = { token: "xoxp-bad", source: "env", profile: "default" }
      recording_auth_test.stub_response("ok" => false, "error" => "invalid_auth")

      expect { run(resolver: resolver_returning(info), auth_test: recording_auth_test) }
        .to raise_error(SlackStatusCli::Cli::Errors::Error, /invalid_auth/)

      expect(output.string).to match(/--rotate/)
    end

    it "raises a scrubbed Cli error when auth.test itself blows up" do
      info = { token: "xoxp-secret-token", source: "file", profile: "default" }
      recording_auth_test.stub_error(RuntimeError.new("boom for xoxp-secret-token"))

      expect { run(resolver: resolver_returning(info), auth_test: recording_auth_test) }
        .to raise_error(SlackStatusCli::Cli::Errors::Error) { |e|
          expect(e.message).not_to include("xoxp-secret-token")
        }
    end
  end
end
