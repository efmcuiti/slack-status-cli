module SlackStatusCli
  module Cli
    module Commands
      # Orchestrates the `doctor` subcommand: resolves a token for the active
      # profile, prints its source plus a redacted token (never the full value),
      # then calls auth.test to confirm the workspace/user it belongs to. Every
      # failure path raises a Cli pod Error (the dispatcher maps it to a non-zero
      # exit) instead of calling exit, and any auth.test error message is scrubbed
      # of token shapes before it surfaces.
      class Doctor
        extend Callable

        DEFAULT_PROFILE = "default".freeze

        def initialize(
          options: {},
          output: $stdout,
          env: ENV,
          resolver: Tokens::Queries::ResolveToken,
          auth_test: Slack::Queries::AuthTest,
          redactor: Queries::RedactedToken,
          hinter: Queries::DoctorHint
        )
          @options = options || {}
          @output = output
          @env = env
          @resolver = resolver
          @auth_test = auth_test
          @redactor = redactor
          @hinter = hinter
        end

        def call
          info = resolve
          output.puts("source : #{info[:source]}")
          output.puts("profile: #{info[:profile]}")
          output.puts("token  : #{redactor.call(token: info[:token])}")

          response = authenticate(info[:token])
          return report_success(response) if response["ok"]

          report_failure(response)
        end

        private

        attr_reader :options, :output, :env, :resolver, :auth_test, :redactor, :hinter

        def resolve
          resolver.call(
            profile: profile,
            cli_token: options[:token],
            config_path: options[:config_path],
            verbose: options[:verbose],
          )
        rescue Tokens::Errors::NotFoundError => e
          raise Errors::Error, "No token resolved for profile '#{profile}'. #{e.message}"
        end

        def authenticate(token)
          auth_test.call(token: token)
        rescue StandardError => e
          raise Errors::Error, "auth.test failed: #{SecretScrubber.call(text: e.message)}"
        end

        def report_success(response)
          output.puts(
            "auth.test ok — workspace=#{response["team"]} user=#{response["user"]} url=#{response["url"]}",
          )
          nil
        end

        def report_failure(response)
          hint = hinter.call(diagnosis: response["error"])
          output.puts(hint) if hint
          raise Errors::Error, "Slack rejected token: #{response["error"]}"
        end

        def profile
          options[:profile] || env["SLACK_STATUS_PROFILE"] || DEFAULT_PROFILE
        end
      end
    end
  end
end
