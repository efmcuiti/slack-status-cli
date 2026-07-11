require "json"

module SlackStatusCli
  module Telemetry
    # Base structured, machine-readable diagnostic logger: one JSON line per
    # event to an injected IO (default $stderr, so $stdout stays clean for human
    # output). The `scrub`/`scrub_message` and `correlation_tags` seams default
    # to identity/empty here so a real secret scrubber and richer correlation
    # can be wired in later (T9.2) without touching call sites. See the
    # ruby-dev observability-guidelines.md for the full contract.
    class StructuredLogger
      VALID_LEVELS = %i[debug info warn error fatal].freeze

      def initialize(io: $stderr, run_id: nil)
        @io = io
        @run_id = run_id
      end

      # message: a CONSTANT string; put variable data in tags so lines aggregate.
      def rich_log(message:, tags: {}, level: :info)
        normalized = normalize_level(level)
        all_tags = scrub(default_tags.merge(tags))
        # Reserved fields merge last so a stray tag can never clobber the
        # normalized message/level and break log queryability.
        payload = all_tags.merge(message: scrub_message(message), level: normalized)
        emit(normalized, payload.to_json)
      end

      # Override per component to add sticky tags that appear on every line.
      def log_tags
        {}
      end

      private

      attr_reader :io, :run_id

      def default_tags
        { caller: component_name }.merge(correlation_tags).merge(log_tags)
      end

      # SEAM: empty by default; carries the per-invocation run_id when present.
      def correlation_tags
        run_id.nil? ? {} : { run_id: run_id }
      end

      # SEAM: identity by default; T9.2 wires SlackStatusCli::SecretScrubber here.
      def scrub(tags)
        tags
      end

      def scrub_message(message)
        message
      end

      # SEAM: where the JSON line goes. An IO sink writes one line and ignores
      # the level; a level-routing sink (e.g. Rails.logger) would use it.
      def emit(_level, json)
        io.puts(json)
      end

      def component_name
        is_a?(::Class) ? name : self.class.name
      end

      def normalize_level(level)
        return :info if level.nil?

        symbol = level.to_sym
        VALID_LEVELS.include?(symbol) ? symbol : :info
      end
    end
  end
end
