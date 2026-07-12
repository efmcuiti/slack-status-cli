require "json"

module SlackStatusCli
  module Telemetry
    # Base structured, machine-readable diagnostic logger: one JSON line per
    # event to an injected IO (default $stderr, so $stdout stays clean for human
    # output). The `scrub`/`scrub_message` seams route the message and every
    # string tag value (including strings nested in Hash/Array values) through
    # SecretScrubber so a token can't leak; non-string scalars keep their JSON
    # type. `correlation_tags` carries a per-invocation run_id (minted by
    # RunContext at the composition root). The full structured-logging contract
    # lives in the ruby-dev skill's
    # observability guidelines (not vendored in this repo); an in-repo telemetry
    # doc follows in T9.5.
    class StructuredLogger
      VALID_LEVELS = %i[debug info warn error fatal].freeze
      RESERVED_KEYS = %w[caller run_id level message].freeze

      def initialize(io: $stderr, run_id: nil)
        @io = io
        @run_id = run_id
      end

      # message: a CONSTANT string; put variable data in tags so lines aggregate.
      def rich_log(message:, tags: {}, level: :info)
        normalized = normalize_level(level)
        # Reserved identity/correlation fields are sourced only from the logger:
        # strip any reserved key a caller passed (so run_id can never be spoofed
        # via tags, even when unset at init) and layer the reserved fields on
        # top. String-keying dedupes symbol- vs string-keyed tags; message uses
        # its own scrub seam.
        supplied = scrub(log_tags.merge(tags)).transform_keys(&:to_s)
                                              .reject { |key, _| RESERVED_KEYS.include?(key) }
        payload = supplied.merge(reserved_fields(message: message, level: normalized))
        emit(normalized, payload.to_json)
      end

      # Override per component to add sticky tags that appear on every line.
      def log_tags
        {}
      end

      private

      attr_reader :io, :run_id

      # Identity, correlation, and message/level — sourced only from the logger,
      # never overridable or spoofable by log_tags/per-call tags.
      def reserved_fields(message:, level:)
        { "caller" => component_name, "level" => level, "message" => scrub_message(message) }
          .merge(correlation_tags.transform_keys(&:to_s))
      end

      # SEAM: empty by default; carries the per-invocation run_id when present.
      def correlation_tags
        run_id.nil? ? {} : { run_id: run_id }
      end

      # SEAM: routes every String *value* reachable in a tag — including those
      # nested inside Hash/Array values — through SecretScrubber so a Slack
      # token can't reach a log line. Hash keys are field names, not secrets,
      # so they're left as-is. Non-string scalars pass through untouched,
      # keeping their JSON type (an integer stays a number).
      def scrub(tags)
        tags.transform_values { |value| scrub_value(value) }
      end

      def scrub_value(value)
        case value
        when ::String then SecretScrubber.call(text: value)
        when ::Hash   then value.transform_values { |nested| scrub_value(nested) }
        when ::Array  then value.map { |nested| scrub_value(nested) }
        else value
        end
      end

      def scrub_message(message)
        SecretScrubber.call(text: message)
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
