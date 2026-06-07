module SlackStatusCli
  module Tokens
    module Backends
      # Reads a Slack token from an environment variable, default
      # `SLACK_STATUS_TOKEN_<PROFILE>` (profile upcased, non-alphanumerics
      # collapsed to `_`). Env vars can't be persisted from a child process, so
      # `#write` raises ManualWriteRequired with shell-export instructions.
      class Env < Base
        def read
          key = env_key
          value = ENV[key]
          if value.nil? || value.strip.empty?
            @last_error = "env var #{key} is empty or unset"
            return nil
          end
          value.strip
        end

        def not_found_hint
          "Export #{env_key}=xoxp-... in your shell, then start a new shell."
        end

        def write(_token)
          raise Errors::ManualWriteRequired, <<~MSG.strip
            Env backend can't persist tokens automatically.
            Add this to your shell profile (~/.zshrc, ~/.bash_profile, etc.):
              export #{env_key}=xoxp-...
            Then start a new shell and re-run: ruby slack_status.rb doctor --profile #{profile}
          MSG
        end

        def location
          env_key
        end

        private

        def env_key
          settings.dig("backend_options", "env", "var") ||
            "SLACK_STATUS_TOKEN_#{sanitized_profile}"
        end

        def sanitized_profile
          profile.to_s.upcase.gsub(/[^A-Z0-9_]/, "_")
        end
      end
    end
  end
end
