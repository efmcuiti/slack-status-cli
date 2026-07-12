require "time"

module SlackStatusCli
  module Cli
    module Commands
      # Orchestrates the `migrate-emojis` subcommand: resolves the source
      # profile's token, lists its custom emoji, hands the map to the
      # EmojiMigration Run command to download images + write aliases/skipped
      # manifests, then (when --to is given) derives the destination admin URL
      # and optionally opens it. Progress is written to the injected output; every
      # failure raises a Cli pod Error (scrubbed) instead of calling exit. The
      # final manual drag-and-drop step is printed rather than blocking on input —
      # the orchestrator stays non-interactive and testable.
      class MigrateEmojis
        extend Callable

        ADMIN_PATH_HINT = "<your-workspace>.slack.com/customize/emoji".freeze

        def initialize(
          options: {},
          output: $stdout,
          clock: -> { ::Time.now },
          resolver: Tokens::Queries::ResolveToken,
          emoji_list: Slack::Queries::EmojiList,
          migrator: EmojiMigration::Commands::Run,
          auth_test: Slack::Queries::AuthTest,
          admin_url_builder: Queries::AdminUrl,
          browser: OpenInBrowser,
          telemetry: Queries::ResolveTelemetry.call
        )
          @options = options || {}
          @output = output
          @clock = clock
          @resolver = resolver
          @emoji_list = emoji_list
          @migrator = migrator
          @auth_test = auth_test
          @admin_url_builder = admin_url_builder
          @browser = browser
          @telemetry = telemetry
        end

        def call
          from = options[:from].to_s.strip
          raise Errors::Error, "migrate-emojis requires --from <profile>" if from.empty?

          emoji_map = fetch_emoji_map(from)
          out_dir = options[:out] || "./emoji-export-#{from}-#{clock.call.strftime("%Y%m%d-%H%M%S")}"
          result = migrator.call(emoji_map: emoji_map, out_dir: out_dir, filter: options[:filter], telemetry: telemetry)

          print_summary(result)
          handle_destination(out_dir)
          result
        end

        private

        attr_reader :options, :output, :clock, :resolver, :emoji_list,
                    :migrator, :auth_test, :admin_url_builder, :browser, :telemetry

        def fetch_emoji_map(from)
          token = resolve(from)
          response =
            begin
              emoji_list.call(token: token)
            rescue StandardError => e
              raise Errors::Error, "emoji.list failed: #{SecretScrubber.call(text: e.message)}"
            end

          return response["emoji"] || {} if response["ok"]

          raise_emoji_list_rejection(from, response["error"])
        end

        def resolve(from)
          resolver.call(profile: from, cli_token: nil, config_path: options[:config_path], verbose: options[:verbose])[:token]
        rescue Tokens::Errors::NotFoundError => e
          raise Errors::Error, "Could not resolve a token for source profile '#{from}'. #{e.message}"
        end

        def raise_emoji_list_rejection(from, error)
          if error == "missing_scope"
            raise Errors::Error,
                  "Token for '#{from}' is missing the `emoji:read` scope. " \
                  "Re-run: ruby slack_status.rb setup --profile #{from} --rotate"
          end

          raise Errors::Error, "Slack rejected emoji.list: #{error}"
        end

        def print_summary(result)
          output.puts(
            "Downloaded #{pluralize(result.downloaded.size, "image")} " \
            "(#{format("%.1f KB", result.total_bytes / 1024.0)}), " \
            "#{pluralize(result.aliases.size, "alias", "aliases")} (see aliases.json), " \
            "#{result.skipped.size} skipped.",
          )
        end

        def handle_destination(out_dir)
          to = options[:to]
          admin_url = derive_admin_url(to) if to && !to.to_s.empty?

          output.puts(manual_instructions(admin_url, out_dir))
          browser.call(url: admin_url) if admin_url && options[:open_browser]
        end

        def derive_admin_url(to)
          token = resolver.call(profile: to, cli_token: nil, config_path: options[:config_path])[:token]
          response = auth_test.call(token: token)
          return nil unless response["ok"]

          url = admin_url_builder.call(workspace_url: response["url"])
          output.puts("Destination emoji admin: #{url}") if url
          url
        rescue StandardError
          nil
        end

        def manual_instructions(admin_url, out_dir)
          <<~MSG.strip
            Next: bulk-upload to your destination workspace.
              1. Open #{admin_url || ADMIN_PATH_HINT}
              2. Click "Add Custom Emoji" -> "Upload Image".
              3. Drag every image from #{::File.expand_path(out_dir)}.
              4. Recreate aliases (see aliases.json) via "Add Custom Emoji" -> "Add Alias".
          MSG
        end

        def pluralize(count, singular, plural = "#{singular}s")
          "#{count} #{count == 1 ? singular : plural}"
        end
      end
    end
  end
end
