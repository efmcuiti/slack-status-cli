module SlackStatusCli
  module Slack
    module Formatters
      # Trims a status text down to `max_len` grapheme clusters, appending
      # `ellipsis` when truncation happens. Blank/short input is returned
      # unchanged (nil normalizes to ""), so the return value is always a
      # String. Cuts at the last whitespace inside the slice when possible,
      # otherwise falls back to a hard cut. When `max_len` cannot fit the
      # ellipsis, it is omitted and the text is hard-cut so the result never
      # exceeds `max_len`.
      class StatusTextTrimmer
        extend Callable

        def initialize(text:, max_len: 100, ellipsis: "…")
          @text = text
          @max_len = max_len
          @ellipsis = ellipsis
        end

        def call
          return text.to_s if text.to_s.strip.empty? || text.grapheme_clusters.length <= max_len

          return text.grapheme_clusters.first([max_len, 0].max).join if max_len <= ellipsis.grapheme_clusters.length

          hard_limit = max_len - ellipsis.grapheme_clusters.length
          slice = text.grapheme_clusters.first(hard_limit).join
          soft = slice.rpartition(/\s/).first
          trimmed = soft.empty? ? slice : soft.rstrip

          "#{trimmed}#{ellipsis}"
        end

        private

        attr_reader :text, :max_len, :ellipsis
      end
    end
  end
end
