require "optparse"

module SlackStatusCli
  module Cli
    module Queries
      # Wraps OptionParser to turn an ARGV-shaped array into the global options
      # Hash the dispatcher reads. `permute!` (not `order!`) so flags may appear
      # before or after the subcommand; the parsed flags are removed in place,
      # leaving the positional args (command + its arguments) behind in `argv`.
      class ParseGlobalFlags
        extend Callable

        def initialize(argv:)
          @argv = argv
        end

        def call
          parser.permute!(argv)
          options
        end

        private

        attr_reader :argv

        def options
          @options ||= {
            profile: nil,
            token: nil,
            config_path: nil,
            verbose: false,
            dry_run: false,
            non_interactive: false,
            rotate: false,
            global: false,
            backend: nil,
            client_id: nil,
            client_secret: nil,
            from: nil,
            to: nil,
            out: nil,
            filter: nil,
            open_browser: true,
          }
        end

        def backends
          Tokens::Commands::WriteToken::BACKEND_CLASSES.keys
        end

        def parser
          ::OptionParser.new do |o|
            o.banner = "Usage: ruby slack_status.rb [options] <command> [args]"
            o.separator ""
            o.separator "Commands: setup, doctor, config get|set, profiles list, migrate-emojis,"
            o.separator "          plus any mode (myth, lunch, break, clear, musical_myth, custom)"
            o.separator ""
            o.on("--profile NAME", "Profile name (default: $SLACK_STATUS_PROFILE or 'default')") { |v| options[:profile] = v }
            o.on("--token TOKEN", "Use this token directly (highest precedence)") { |v| options[:token] = v }
            o.on("--config PATH", "Path to config.yml (default: ~/.config/slack-status-cli/config.yml)") { |v| options[:config_path] = v }
            o.on("-v", "--verbose", "Print token source to stderr") { options[:verbose] = true }
            o.on("--dry-run", "Resolve and report without performing side effects") { options[:dry_run] = true }
            o.on("--non-interactive", "Fail instead of prompting") { options[:non_interactive] = true }
            o.on("--rotate", "(setup) Overwrite an existing token") { options[:rotate] = true }
            o.on("--global", "(setup) Configure global defaults only") { options[:global] = true }
            o.on("--backend NAME", backends, "(setup) Storage backend: #{backends.join('|')}") { |v| options[:backend] = v }
            o.on("--client-id ID", "(setup) Slack App client_id") { |v| options[:client_id] = v }
            o.on("--client-secret SECRET", "(setup) Slack App client_secret (prefer prompt)") { |v| options[:client_secret] = v }
            o.on("--from PROFILE", "(migrate-emojis) Source profile to download emojis from") { |v| options[:from] = v }
            o.on("--to PROFILE", "(migrate-emojis) Destination profile (used to derive admin URL)") { |v| options[:to] = v }
            o.on("--out DIR", "(migrate-emojis) Output directory (default: ./emoji-export-<from>-<timestamp>)") { |v| options[:out] = v }
            o.on("--filter REGEX", "(migrate-emojis) Only download emoji whose name matches REGEX (case-insensitive)") { |v| options[:filter] = v }
            o.on("--no-open", "(migrate-emojis) Do not open the destination admin URL automatically") { options[:open_browser] = false }
            o.on("-h", "--help", "Show this help") { puts o; exit 0 }
          end
        end
      end
    end
  end
end
