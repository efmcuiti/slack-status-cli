module SlackStatusCli
  module Tokens
    module Queries
      # Builds the multi-line, human-facing message raised as NotFoundError when
      # no token resolves for a profile. Extracted verbatim from the legacy
      # `TokenResolver#friendly_not_found_message`: it names the profile, surfaces
      # the tried backend's own not_found_hint (or, for an unconfigured
      # non-default profile, points at the config path), lists the three
      # remediation steps, and explains when SLACK_SECRET_TOKEN is being ignored
      # on purpose to avoid cross-workspace token leakage.
      class NotFoundMessage
        extend Callable

        DEFAULT_PROFILE = "default".freeze
        LEGACY_ENV_VAR = "SLACK_SECRET_TOKEN".freeze

        def initialize(profile:, config_path:, tried_backend: nil, profile_configured: false)
          @profile = profile
          @config_path = config_path
          @tried_backend = tried_backend
          @profile_configured = profile_configured
        end

        def call
          lines = ["No Slack token found for profile '#{profile}'."]

          if tried_backend
            lines << "Tried #{tried_backend.source_label} but it returned no token."
            hint = tried_backend.not_found_hint
            hint.each_line { |line| lines << "  #{line.chomp}" } if hint
          elsif !profile_configured && profile != DEFAULT_PROFILE
            lines << "Profile '#{profile}' is not configured in #{config_path}."
          end

          lines.concat(remediation_steps)
          lines.concat(legacy_note) if legacy_note?

          lines.join("\n")
        end

        private

        attr_reader :profile, :config_path, :tried_backend, :profile_configured

        def remediation_steps
          [
            "",
            "Fix one of:",
            "  1. ruby slack_status.rb setup --profile #{profile}",
            "  2. export #{EnvVarName.call(profile: profile)}=xoxp-... in your shell",
            "  3. ruby slack_status.rb --token xoxp-... --profile #{profile} <mode>"
          ]
        end

        def legacy_note?
          non_empty?(ENV[LEGACY_ENV_VAR]) && (profile != DEFAULT_PROFILE || profile_configured)
        end

        def legacy_note
          [
            "",
            "Note: SLACK_SECRET_TOKEN is set but intentionally ignored for",
            "profile '#{profile}' to avoid sending a token from a different",
            "workspace. The legacy fallback only applies to the `default`",
            "profile when no backend is configured."
          ]
        end

        def non_empty?(value)
          !value.nil? && !value.to_s.strip.empty?
        end
      end
    end
  end
end
