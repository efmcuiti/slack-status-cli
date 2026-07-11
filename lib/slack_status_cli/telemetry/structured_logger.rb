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
        # Reserved identity/correlation fields (caller, run_id, level) are merged
        # over the overridable log_tags/per-call tags so neither can spoof them;
        # string-keying then dedupes symbol- vs string-keyed tags. message is
        # applied last through its own scrub seam. Reserved fields always win.
        reserved = { caller: component_name, level: normalized }.merge(correlation_tags)
        all_tags = scrub(log_tags.merge(tags).merge(reserved)).transform_keys(&:to_s)
        payload = all_tags.merge("message" => scrub_message(message))
        emit(normalized, payload.to_json)
      end

      # Override per component to add sticky tags that appear on every line.
      def log_tags
        {}
      end

      private

      attr_reader :io, :run_id

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

      # The logger is always instantiated, so the component is this instance's
      # class. Anonymous subclasses (used in specs) have a nil name, so fall
      # back to the superclass name to keep `caller` a stable, non-null tag.
      def component_name
        self.class.name || self.class.superclass.name
      end

      def normalize_level(level)
        return :info unless level.respond_to?(:to_sym)

        symbol = level.to_sym
        VALID_LEVELS.include?(symbol) ? symbol : :info
      end
    end
  end
end
