require "open3"
require "json"

module SlackStatusCli
  module Tokens
    module Backends
      # Reads a Slack token from a Dashlane Secure Note via the `dcli` CLI.
      #
      # Uses `dcli note --output json title=<title>` rather than the
      # `dcli read dl://<title>` URL form because the URL parser treats `/` as
      # the title/field separator, which breaks any title containing a slash
      # (e.g. `slack-status-cli/<profile>-token`). Writes are not supported: the
      # personal `dcli` exposes no unattended write API, so `#write` raises
      # ManualWriteRequired with copy-paste instructions.
      class Dashlane < Base
        def initialize(profile:, settings: {}, runner: Open3)
          super(profile: profile, settings: settings)
          @runner = runner
        end

        def read
          stdout, stderr, status = runner.capture3(
            "dcli", "note", "--output", "json", "title=#{title}"
          )
          unless status.success?
            @last_error = strip_ansi(stderr).strip
            return nil
          end

          notes =
            begin
              JSON.parse(stdout)
            rescue JSON::ParserError => e
              @last_error = "dcli returned non-JSON output (#{e.message})"
              return nil
            end

          if notes.nil? || notes.empty?
            @last_error = "no Secure Note matches title=#{title} (local vault may be stale; try `dcli sync`)"
            return nil
          end

          content = notes.first["content"].to_s.strip
          if content.empty?
            @last_error = "Secure Note '#{title}' exists but its content is empty"
            return nil
          end
          content
        rescue Errno::ENOENT
          @last_error = "`dcli` not found in PATH"
          nil
        end

        def not_found_hint
          case @last_error
          when /no Secure Note matches/
            <<~HINT.strip
              No Secure Note titled '#{title}' was found in your local Dashlane vault.
              If you just created the note, refresh the local cache:
                dcli sync
              If the note doesn't exist yet, create it with:
                1. Open the Dashlane app.
                2. Add a Secure Note titled EXACTLY: #{title}
                3. Paste your Slack user token (xoxp-...) into the content field.
              To re-print the token and title, run:
                ruby slack_status.rb setup --profile #{profile} --rotate
            HINT
          when /content is empty/
            "Secure Note '#{title}' exists but its content is empty. Paste your xoxp-... token into it."
          when "`dcli` not found in PATH"
            "Install the Dashlane CLI: brew install dashlane/tap/dashlane-cli"
          when nil, ""
            nil
          else
            "dcli error: #{@last_error}"
          end
        end

        def write(token)
          raise Errors::ManualWriteRequired, <<~MSG.strip
            Dashlane CLI does not support unattended writes. Add the token manually:
              1. Open the Dashlane app (or run `dcli sync`).
              2. Create a Secure Note titled exactly: #{title}
              3. Paste the token (printed once below) into the content field.
              4. Re-run: ruby slack_status.rb doctor --profile #{profile}

            Token (copy now, it will not be shown again):
            #{token}
          MSG
        end

        def location
          token_ref
        end

        def token_ref
          ref = settings["token_ref"]
          return ref if ref && !ref.to_s.strip.empty?

          "dl://#{title_prefix}/#{profile}-token"
        end

        private

        attr_reader :runner

        def title
          token_ref.sub(%r{^dl://}, "")
        end

        def title_prefix
          settings.dig("backend_options", "dashlane", "title_prefix") || "slack-status-cli"
        end

        def strip_ansi(value)
          value.to_s.gsub(/\e\[[0-9;]*m/, "")
        end
      end
    end
  end
end
