require "fileutils"

module SlackStatusCli
  module Tokens
    module Backends
      # Reads/writes a Slack token from a perm-guarded local file, default
      # `~/.config/slack-status-cli/tokens/<profile>`. The read path refuses a
      # file whose mode grants group/other any bits (anything but 0600-style),
      # so a misconfigured permission can't silently leak the secret.
      #
      # NOTE: this class is named `File`, which shadows Ruby's top-level
      # `::File` inside the class body. Every filesystem call below is therefore
      # qualified as `::File` / `::FileUtils` on purpose — do not "simplify".
      class File < Base
        DEFAULT_TOKEN_DIR = ::File.expand_path("~/.config/slack-status-cli/tokens").freeze

        def read
          unless ::File.exist?(path)
            @last_error = "file does not exist"
            return nil
          end
          unless permissions_ok?
            @last_error = "permissions too open"
            return nil
          end
          stripped = ::File.read(path).strip
          stripped.empty? ? nil : stripped
        end

        def not_found_hint
          case @last_error
          when "file does not exist"
            "Token file not found at #{path}. Re-run setup --profile #{profile} --rotate."
          when "permissions too open"
            "Token file #{path} has overly permissive permissions. Run: chmod 600 #{path}"
          end
        end

        def write(token)
          ::FileUtils.mkdir_p(::File.dirname(path))
          ::File.write(path, "#{token}\n")
          ::File.chmod(0o600, path)
        end

        def location
          path
        end

        private

        def path
          override = settings.dig("backend_options", "file", "path")
          return ::File.expand_path(override) if override

          ::File.join(DEFAULT_TOKEN_DIR, profile)
        end

        # Refuses to read a token file with group/other readable bits set, so a
        # misconfigured permission doesn't silently leak the secret.
        def permissions_ok?
          mode = ::File.stat(path).mode & 0o777
          return true if (mode & 0o077).zero?

          warn "[slack-status-cli] refusing to read #{path}: permissions #{mode.to_s(8)} are too open (chmod 600)."
          false
        end
      end
    end
  end
end
