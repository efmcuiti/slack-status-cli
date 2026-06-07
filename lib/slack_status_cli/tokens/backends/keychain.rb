require "open3"

module SlackStatusCli
  module Tokens
    module Backends
      # Reads/writes a Slack token from the macOS login Keychain via the
      # `security` CLI. The generic-password item is keyed by service (default
      # `slack-status-cli`) and account (default: the profile name). Writes use
      # `-U` so an existing item is updated in place rather than duplicated.
      class Keychain < Base
        KEYCHAIN_SERVICE = "slack-status-cli".freeze

        def initialize(profile:, settings: {}, runner: Open3)
          super(profile: profile, settings: settings)
          @runner = runner
        end

        def read
          stdout, stderr, status = runner.capture3(
            "security", "find-generic-password", "-s", service, "-a", account, "-w"
          )
          unless status.success?
            @last_error = stderr.to_s.strip
            return nil
          end
          stripped = stdout.to_s.strip
          stripped.empty? ? nil : stripped
        rescue Errno::ENOENT
          @last_error = "`security` not found in PATH (macOS only)"
          nil
        end

        def not_found_hint
          if @last_error&.include?("could not be found")
            "No Keychain item for service=#{service} account=#{account}. Re-run setup --profile #{profile} --rotate."
          elsif @last_error == "`security` not found in PATH (macOS only)"
            @last_error
          end
        end

        def write(token)
          _stdout, stderr, status = runner.capture3(
            "security", "add-generic-password",
            "-s", service, "-a", account, "-w", token, "-U"
          )
          return if status.success?

          raise Errors::WriteError, "security add-generic-password failed: #{stderr.to_s.strip}"
        rescue Errno::ENOENT
          raise Errors::WriteError, "`security` not found in PATH; Keychain backend requires macOS."
        end

        def location
          "#{service}/#{account}"
        end

        private

        attr_reader :runner

        def service
          settings.dig("backend_options", "keychain", "service") || KEYCHAIN_SERVICE
        end

        def account
          settings.dig("backend_options", "keychain", "account") || profile
        end
      end
    end
  end
end
