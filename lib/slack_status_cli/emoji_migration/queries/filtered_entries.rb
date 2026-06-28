module SlackStatusCli
  module EmojiMigration
    module Queries
      # Splits a Slack `emoji.list` map into downloadable images, alias pointers,
      # and unparseable leftovers, optionally narrowing to names matching a
      # case-insensitive regex first.
      #
      # Slack entries take two shapes:
      #   "phoenix_ash"   => "https://emoji.slack-edge.com/.../abc.png"  (real image)
      #   "phoenix_alias" => "alias:phoenix_ash"                          (alias)
      #
      # Anything whose value is neither an http(s) URL nor an alias (nil, "",
      # a bogus scheme) is reported in `:skipped` rather than silently dropped.
      class FilteredEntries
        extend Callable

        ALIAS_PREFIX = "alias:".freeze

        def initialize(emoji_map:, pattern: nil)
          @emoji_map = emoji_map || {}
          @pattern = pattern
        end

        def call
          real = {}
          aliases = {}
          skipped = []

          filtered.each do |name, value|
            string = value.to_s
            if string.start_with?(ALIAS_PREFIX)
              aliases[name] = string.delete_prefix(ALIAS_PREFIX)
            elsif real_url?(string)
              real[name] = value
            else
              skipped << name
            end
          end

          { real: real, aliases: aliases, skipped: skipped }
        end

        private

        attr_reader :emoji_map, :pattern

        def filtered
          return emoji_map if pattern.nil? || pattern.empty?

          regexp = Regexp.new(pattern, Regexp::IGNORECASE)
          emoji_map.select { |name, _| regexp.match?(name.to_s) }
        end

        def real_url?(string)
          string.start_with?("http://", "https://")
        end
      end
    end
  end
end
