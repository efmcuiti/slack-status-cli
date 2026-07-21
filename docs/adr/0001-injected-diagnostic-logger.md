---
status: accepted
---

# Injected diagnostic logger with pluggable seams

Diagnostic logging is provided by a base `StructuredLogger` that exposes a single `rich_log(message:, tags:, level:)` method plus an overridable `log_tags` hook, with environment-specific behavior hidden behind private seams (`scrub`, `correlation_tags`, `emit`). Orchestrators receive it through an injected `telemetry:` keyword that defaults to a no-op `NullLogger`, and the composition root (`Cli::Queries::ResolveTelemetry`) decides — from `SLACK_STATUS_LOG` — whether to inject a real logger. We chose this over a global logger singleton or a `Rails`-style mixin because it keeps pure Callables logger-free, makes "off by default" the literal default, and lets specs assert emitted events by injecting a `CapturingTelemetry` fake instead of intercepting global IO.

## Considered options

- **Global logger singleton** (e.g. a `SlackStatusCli.logger`). Rejected: it is a hidden dependency every object can reach, "off by default" becomes a runtime flag rather than a type, and tests must stub a global and scrub real IO.
- **Mixin / `include`** (negotiatus' Rails-idiomatic form, where a service `include`s a logging module). Rejected for this CLI: it bolts a cross-cutting concern onto classes that should stay pure, and there is no `Rails.logger`/request context to lean on. The mixin remains the right choice in the Rails app; the two share the identical `rich_log`/`log_tags`/seam vocabulary, so a pattern moves between them as a re-wiring, not a rewrite.
- **Injected collaborator** (chosen). A real `NullLogger` off-switch, a trivial fake for specs, and no global state.

## Consequences

- Every orchestrator that logs must declare a `telemetry:` seam and be wired at its composition-root entrypoint; a pod that is never wired stays silent (acceptable — telemetry is opt-in per orchestrator).
- The `scrub` seam is the single enforcement point for "never log a secret value"; bypassing it by hand-building a payload would defeat redaction.
- Reserved fields (`caller`, `level`, `message`, `run_id`) are owned by the logger and cannot be overridden by caller tags, so a stray tag can never spoof identity or correlation.

See [../observability.md](../observability.md) for the usage-facing contract.
