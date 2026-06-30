require "open3"

module SlackStatusCli
  module Cli
    module Commands
      # Opens a URL in the user's default browser by shelling out to the
      # platform launcher. The URL is passed as its own argv element (never
      # interpolated into a shell string) so spaces and shell metacharacters
      # can't trigger injection. A nil/empty URL is a no-op.
      class OpenInBrowser
        extend Callable

        def initialize(url:, runner: Open3, platform: RUBY_PLATFORM)
          @url = url
          @runner = runner
          @platform = platform
        end

        def call
          return if url.nil? || url.to_s.empty?

          runner.capture3(*launcher, url.to_s)
          nil
        rescue ::Errno::ENOENT
          # Opening a browser is best-effort: a missing launcher (e.g. no
          # xdg-open on a headless box) must not crash setup/orchestration.
          nil
        end

        private

        attr_reader :url, :runner, :platform

        # `start` is a cmd.exe built-in, not an executable, so Windows needs
        # `cmd /c start "" <url>` (the empty "" is the window-title arg `start`
        # would otherwise steal the URL for).
        def launcher
          case platform
          when /darwin/ then ["open"]
          when /mswin|mingw|cygwin/ then ["cmd", "/c", "start", ""]
          else ["xdg-open"]
          end
        end
      end
    end
  end
end
