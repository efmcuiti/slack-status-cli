# Spec-only telemetry collaborator: records every `rich_log` call (message,
# tags, level) so specs can assert *what* an orchestrator logged on the
# diagnostic channel without touching real IO. Mirrors the
# StructuredLogger/NullLogger surface (`rich_log(message:, tags:, level:)`)
# and, like NullLogger, returns nil.
#
# Pods take a `telemetry:` keyword (defaulting to a real NullLogger); specs
# inject a CapturingTelemetry instead and read `#entries` / `#messages` /
# `#entry_for`.
class CapturingTelemetry
  Entry = Struct.new(:message, :tags, :level, keyword_init: true)

  attr_reader :entries

  def initialize
    @entries = []
  end

  def rich_log(message:, tags: {}, level: :info)
    @entries << Entry.new(message: message, tags: tags, level: level)
    nil
  end

  def messages
    entries.map(&:message)
  end

  def entry_for(message)
    entries.find { |entry| entry.message == message }
  end
end
