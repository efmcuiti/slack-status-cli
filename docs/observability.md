# Observability

Structured, machine-readable diagnostic logging — how to turn it on, the `rich_log` contract, and the two-channel rule that keeps it separate from human output. Off by default; the design rationale lives in [adr/0001-injected-diagnostic-logger.md](adr/0001-injected-diagnostic-logger.md).

## The two channels (never merged)

The CLI has two distinct output channels, and they must stay separate:

- **Human-progress channel** — `CliPrompt`, `puts`, the `😴`/`✓`/`✗` lines. Goes to **`$stdout`**. This is what a person reads.
- **Diagnostic channel** — one JSON object per line for after-the-fact analysis (failures, long-running flows, concurrency, external calls). Goes to **`$stderr`**. This is what a machine aggregates.

Keeping the diagnostic stream on `$stderr` means `$stdout` stays clean for humans and for piping. Nothing routes a value through both channels — they are independent seams.

## Enabling it

Diagnostic logging is **off by default**: every `rich_log` call no-ops through a `NullLogger` until the composition root injects a real logger. The switch is the `SLACK_STATUS_LOG` environment variable, read once per invocation by `Cli::Queries::ResolveTelemetry`:

| `SLACK_STATUS_LOG` | Result |
| --- | --- |
| unset / `""` / `off` | `NullLogger` (silent) |
| `json` | real `StructuredLogger` → `$stderr` |
| `debug` / `info` / `warn` / `error` / `fatal` | real `StructuredLogger` → `$stderr` |
| anything else (e.g. a typo like `josn`) | `NullLogger` (stays off) |

Matching is case- and whitespace-insensitive. Enablement is an allow-list, so a typo can never *accidentally* turn logging on.

```bash
# JSON telemetry on stderr, human summary on stdout, kept in separate streams:
SLACK_STATUS_LOG=json ruby slack_status.rb migrate-emojis --from work 2>telemetry.log

# Musical-myth loop with verbose (debug) ticks:
SLACK_STATUS_LOG=debug ruby slack_status.rb musical_myth 2>telemetry.log

# Off (default): stderr stays empty.
ruby slack_status.rb migrate-emojis --from work 2>telemetry.log && wc -l telemetry.log   # → 0
```

## The `rich_log` contract

`StructuredLogger` exposes one public method plus one overridable hook:

```ruby
telemetry.rich_log(message:, tags: {}, level: :info)
```

- **`message`** is a **constant** string — put variable data in `tags`, never in the message. Stable messages aggregate and alert cleanly; interpolated ones are unsearchable.
- **`tags`** is a hash of structured fields. Non-string scalars keep their JSON type (an integer stays a number).
- **`level`** is one of `:debug :info :warn :error :fatal` (`VALID_LEVELS`). An invalid or non-symbolizable level falls back to `:info`. The IO sink writes every level (the level is a field, not a filter); a level-routing sink like `Rails.logger` would honor it.

Every emitted line also carries three **reserved fields** the logger owns and a caller can never override or spoof via tags:

- `caller` — the component class name (e.g. `SlackStatusCli::EmojiMigration::Commands::Run`).
- `level` — the normalized level.
- `message` — the (scrubbed) constant message.
- `run_id` — the per-invocation correlation id, when one was set at construction (see seams below).

### `log_tags` — sticky per-component tags

Override `log_tags` on a subclass to attach tags that should appear on **every** line for that component (primary entity IDs, etc.) rather than repeating them at each call site. A per-call `tags:` value wins over `log_tags` on a key collision; both lose to the reserved fields above.

### Example output

```json
{"images":1,"aliases":1,"unparseable":0,"caller":"SlackStatusCli::EmojiMigration::Commands::Run","level":"info","message":"emoji export started","run_id":"9f2c1a7b8e3d4f60"}
{"name":"rocket","extension":"png","bytes":2048,"caller":"SlackStatusCli::EmojiMigration::Commands::Run","level":"info","message":"emoji downloaded","run_id":"9f2c1a7b8e3d4f60"}
```

Each line is a single valid JSON object; every line from one CLI run shares the same `run_id`.

## The seams

`StructuredLogger` keeps environment-specific behavior behind private seams with sensible defaults, so the same contract works in a CLI and (with different adapters) in a Rails app.

- **`scrub` / `scrub_message` → `SecretScrubber`.** The message and every **string value** reachable in a tag — including strings nested inside Hash/Array values — are routed through `SecretScrubber` before emit, so a `xox…` token can never reach a log line. Hash *keys* are field names, not secrets, and are left as-is. This is the enforcement point for the absolute rule: **never log a secret value.** Do not string-build a payload yourself and bypass it.
- **`correlation_tags` → `run_id`.** A per-invocation `run_id` (`Telemetry::RunContext.generate`, an 8-byte `SecureRandom.hex`) is minted once at the composition root and carried on every line, so concurrent work (e.g. threaded emoji downloads) and multi-step flows correlate to one invocation.
- **`emit` → the sink.** Default is `io.puts` to the injected IO (`$stderr`). A level-routing sink would branch on level here.

## What the orchestrators emit

Telemetry is emitted **alongside** the human channel, never replacing it. The three adopted orchestrators:

| Orchestrator | message | level | tags |
| --- | --- | --- | --- |
| `EmojiMigration::Commands::Run` | `emoji export started` | info | `images, aliases, unparseable` |
| | `emoji downloaded` | info | `name, extension, bytes` |
| | `emoji skipped` | warn | `name, reason` |
| | `emoji export finished` | info | `downloaded, aliases, skipped, total_bytes` |
| `Oauth::Commands::Install` | `oauth install started` | info | `port, scopes` |
| | `oauth token exchanged` | info | `user_id, team_id, team_name` (never the token) |
| | `oauth scope granted` | info | `scope` |
| | `oauth token exchange failed` | error | `reason` (scrubbed), then re-raise |
| `Slack::Commands::RunMusicalLoop` | `musical loop tick` | debug | `state, interval` |
| | `musical track changed` | info | `name, artist` |
| | `musical tick failed` | warn | `error, reason` |

## Adding telemetry to a new orchestrator

1. Take a `telemetry:` keyword defaulting to `Telemetry::NullLogger.new` — the orchestrator stays silent until something injects a real logger.
2. Emit `rich_log` at business/operationally relevant points: start/finish, per-item success/skip, and failures at `:warn`/`:error` **with identifying tags** (IDs over counts — counts lose the audit trail).
3. Wire it at the **composition root** (the `Cli::Commands::*` entrypoint), which resolves `Cli::Queries::ResolveTelemetry.call(env:)` and threads the result down. Only one entrypoint runs per invocation, so there is exactly one `run_id` per CLI run.

Pure queries/commands stay logger-free; only orchestrators take the seam.

## The review gate

Telemetry is logic — level selection, tag shape, scrubbing, success/failure branching — so it follows normal TDD: write a failing spec first. The spec-only `CapturingTelemetry` fake (records `rich_log` calls as `message`/`tags`/`level`) is the cleanest collaborator for asserting *what* was logged without touching real IO. The pure-presentation carve-out does **not** apply to telemetry.
