# slack-status-cli

A single-purpose CLI that sets a Slack user's status (mythological modes, now-playing, custom) across multiple profiles. This glossary pins the project's domain vocabulary; it currently covers the telemetry/observability pod and grows as other pods surface terms worth fixing.

## Language

### Telemetry / observability

**Diagnostic log**:
The stream of structured JSON-line events emitted for after-the-fact analysis (failures, long flows, concurrency, external calls). Off by default and machine-facing — distinct from anything a person reads.
_Avoid_: "logging" unqualified, "debug output".

**Telemetry channel**:
The diagnostic-event stream, written to `$stderr`.
_Avoid_: "logs" (ambiguous with the human channel).

**Human-progress channel**:
The user-facing output stream (`CliPrompt`, `puts`, the `✓`/`😴` lines), written to `$stdout`. Never merged with the telemetry channel.
_Avoid_: "console output", "stdout logging".

**StructuredLogger**:
The base diagnostic logger. Exposes `rich_log` plus the `log_tags` hook and keeps environment-specific behavior behind the `scrub`, `correlation_tags`, and `emit` seams.
_Avoid_: "the logger" (say which), "Logger".

**NullLogger**:
The no-op `StructuredLogger` subclass — the off switch and the safe default for any `telemetry:` seam. `rich_log` returns nil and writes nothing.
_Avoid_: "silent logger", "fake logger" (that's `CapturingTelemetry`, a spec fake).

**rich_log**:
The single public logging entry point: `rich_log(message:, tags:, level:)`. `message` is a constant string; variable data goes in `tags`.
_Avoid_: "log", "write".

**log_tags**:
The overridable hook holding tags that appear on every line for a component. Per-call tags win over it; reserved fields win over both.
_Avoid_: "default tags", "base tags".

**run_id / RunContext**:
`run_id` is the per-invocation correlation id shared by every line of one CLI run; `RunContext.generate` mints it (an 8-byte `SecureRandom.hex`) once at the composition root.
_Avoid_: "request id", "trace id" (Rails/Datadog terms), "session id".

**scrub seam**:
The `scrub`/`scrub_message` seam that routes the message and every string tag value (nested included) through `SecretScrubber` before emit, so a `xox…` token can never reach a line. The enforcement point for "never log a secret value".
_Avoid_: "redact", "filter" (name the seam).

**correlation_tags seam**:
The seam that carries the `run_id` onto every line. Empty by default; a Rails adapter would carry Datadog trace/span ids here instead.
_Avoid_: "context tags", "metadata".

**telemetry: seam**:
The injected keyword (default `NullLogger.new`) by which an orchestrator receives its logger. The composition root injects a real logger via `Cli::Queries::ResolveTelemetry`.
_Avoid_: "logger argument", "logger dependency".

**Composition root**:
The `Cli::Commands::*` entrypoint that resolves telemetry from `SLACK_STATUS_LOG` and threads it into the orchestrators. One entrypoint runs per invocation, so there is one `run_id` per run.
_Avoid_: "the CLI", "main", "bootstrap".

## Example dialogue

> **Dev:** The emoji export failed silently in prod — can we see what happened?
> **Maintainer:** It's off by default, so re-run with `SLACK_STATUS_LOG=json`. That flips the composition root from a NullLogger to a real StructuredLogger and puts the diagnostic channel on stderr.
> **Dev:** Will the human summary still show?
> **Maintainer:** Yes — the human-progress channel is stdout, the telemetry channel is stderr. They never merge. You'll get `emoji skipped` lines at `:warn` with the name and reason in tags.
> **Dev:** And the token won't leak into those lines?
> **Maintainer:** Right — the scrub seam runs every message and string tag value through `SecretScrubber` first. Grep the run by its `run_id` and you'll see the whole invocation.
