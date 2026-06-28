require "uri"

module SlackStatusCli
  module EmojiMigration
    module Queries
      # Picks a file extension for a downloaded emoji. Slack's image URLs carry a
      # clean suffix (.png/.gif/.jpg), so that wins when recognized; otherwise we
      # sniff the first few magic bytes and fall back to "bin".
      class ExtensionFor
        extend Callable

        KNOWN_SUFFIXES = %w[png gif jpg jpeg webp].freeze

        def initialize(url:, body:)
          @url = url
          @body = body
        end

        def call
          from_url = File.extname(URI(@url.to_s).path).delete_prefix(".").downcase
          return from_url if KNOWN_SUFFIXES.include?(from_url)

          sniff(@body.to_s.b)
        end

        private

        def sniff(bytes)
          case bytes[0, 8]
          when /\A\x89PNG/n then "png"
          when /\AGIF8/n then "gif"
          when /\A\xFF\xD8\xFF/n then "jpg"
          else "bin"
          end
        end
      end
    end
  end
end
