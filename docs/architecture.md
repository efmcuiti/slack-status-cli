# Architecture

Project layout, the token-resolver design, and a few "we considered X" notes so future contributors don't relitigate the obvious questions.

## Project structure

```
.
├── slack_status.rb              # CLI entry point: ~40-line dispatcher → Cli::Queries/Commands
├── Gemfile                      # Minimal: webrick (extracted from stdlib in Ruby 3.0)
├── lib/
│   ├── slack_status_cli.rb      # Root namespace + autoload entry point for the Callable pods
│   ├── slack_status_cli/        # Callable pods: slack/, music/, tokens/, oauth/, cli/, emoji_migration/, telemetry/ (+ callable.rb, secret_scrubber.rb)
│   └── cli_prompt.rb            # Interactive UX helpers ([Y/n], secret input, emoji progress, scrub_secrets)
├── docs/
│   ├── setup.md                 # Slack App + manifest, prerequisites, setup walkthrough
│   ├── security.md              # Token storage strategies, Dashlane, threat model, rotation
│   ├── usage.md                 # Full CLI reference: flags, modes, subcommands
│   ├── musical-myth.md          # Now-playing detection deep-dive
│   ├── examples.md              # Copy-pasteable invocations
│   ├── observability.md         # Diagnostic telemetry: SLACK_STATUS_LOG, rich_log contract, seams
│   ├── troubleshooting.md       # Notes, gotchas, Slack error decoder
│   ├── architecture.md          # This file
│   ├── adr/                     # Architecture Decision Records (0001-…)
│   └── slack-app-manifest.yml   # Slack App manifest (paste at app creation time)
├── CONTEXT.md                   # Domain glossary (telemetry vocabulary; grows per pod)
└── README.md
```

## Callable conventions

Business logic lives in small, single-purpose **Callable** objects under `lib/slack_status_cli/<pod>/` — `queries/` read and return a value, `commands/` perform a side effect. Each exposes one public entry point, `.call`, and nothing else. The following conventions keep every callable shaped the same way; `lib/slack_status_cli/callable.rb` is the canonical reference and `Queries::FilteredEntries` a representative example.

- **`extend Callable`, not `include`.** The `Callable` module defines an instance-style `call` that becomes the class method via `extend`. The class method forwards args **and the block** explicitly — `new(*args, **kwargs).call(&block)` — never the terser `new(...).call`, which silently hands the block to `initialize` (where it is dropped) instead of to `#call`. Orchestrators like `Oauth::Commands::Install` rely on the block reaching `#call`.
- **Private `attr_reader` for constructor params.** `initialize` assigns each keyword to an `@ivar`; everything below it reads through a `private attr_reader` rather than touching the raw `@ivar`. This keeps the inputs named, read-only, and trivially stubbable in specs.

```ruby
class SanitizeFilename
  extend Callable

  def initialize(name:)
    @name = name
  end

  def call
    name.to_s.gsub(UNSAFE, "_")
  end

  private

  attr_reader :name
end
```

- **Each pod owns its error vocabulary.** A pod defines its own `Errors` module with a base `Error < StandardError` plus specific subclasses (e.g. `EmojiMigration::Errors::MissingScope`), and raises those rather than a bare `RuntimeError`/`StandardError`. Callers rescue the pod's base `Error` to scope failure handling.
- **`::`-qualify top-level stdlib constants** inside a namespaced pod (`::File`, `::FileUtils`, `::Net::HTTP`) so a future same-named constant in the namespace can never shadow the standard library by accident.
- **Freeze string constants** (`FILENAME = "skipped.json".freeze`, `UNSAFE = /.../.freeze`) so shared literals can't be mutated in place.
- **Never log secret values.** Print the *source* of a resolved token, not the value (`resolved from dashlane:dl://...`), and route any caught exception through `CliPrompt.scrub_secrets`, which replaces `xox[a-z]-…` patterns with `xox?-…XXXX`. A real token in any log line is a bug.

## Telemetry / observability

Diagnostic logging lives in its own `Telemetry` pod, kept strictly separate from the human-progress channel (`CliPrompt` on `$stdout`). The diagnostic channel emits one JSON line per event to `$stderr` and is **off by default**.

```
lib/slack_status_cli/telemetry/
  structured_logger.rb   # base logger: rich_log + log_tags + scrub/correlation_tags/emit seams
  null_logger.rb         # no-op subclass — the off switch and default telemetry: value
  run_context.rb         # RunContext.generate — per-invocation run_id (SecureRandom.hex)
lib/slack_status_cli/cli/queries/resolve_telemetry.rb   # composition-root switch (reads SLACK_STATUS_LOG)
```

The integration follows the **injected-collaborator** convention: pure queries/commands stay logger-free, while orchestrators take a `telemetry:` keyword defaulting to `Telemetry::NullLogger.new`. The composition root — each `Cli::Commands::*` entrypoint — calls `Cli::Queries::ResolveTelemetry.call(env:)` and threads the resolved logger down (`Run`, `Install`, and `UpdateStatus → RunMusicalLoop`). A logger is resolved once per invocation, so every line shares one `run_id`.

Two invariants are enforced structurally rather than by convention: the `scrub` seam routes every message and string tag value through `SecretScrubber` (never log a secret), and the reserved fields `caller`/`level`/`message`/`run_id` are owned by the logger and can't be overridden by caller tags. See [observability.md](observability.md) for the usage-facing contract and [adr/0001-injected-diagnostic-logger.md](adr/0001-injected-diagnostic-logger.md) for why injected-over-mixin/global.

## Token resolver

`SlackStatusCli::Tokens::Queries::ResolveToken.call(profile:, cli_token:, config_path:)` walks a fixed precedence chain and returns `{ token:, source:, profile: }`. First non-empty wins; no silent fallbacks.

```
1. --token CLI flag           (cli:--token)
2. SLACK_STATUS_TOKEN_<PROFILE> env var
3. Config-driven backend      (profile entry merged with global; profile wins on collision)
     dashlane  → `dcli read dl://<title>`
     keychain  → `security find-generic-password -s slack-status-cli -a <profile> -w`
     file      → ~/.config/slack-status-cli/tokens/<profile>  (refuses to read if mode allows group/other)
     env       → ENV[backend_options.env.var || SLACK_STATUS_TOKEN_<PROFILE>]
4. SLACK_SECRET_TOKEN         (legacy fallback — see scope below)
```

The legacy `SLACK_SECRET_TOKEN` is **only** consulted when **all** of the following are true:

- the active profile is `default`,
- no `profiles.default` block exists in the config,
- and no backend resolved a token in step 3.

For any non-default profile, or any profile that has an explicit `profiles.<name>` block, the legacy env var is intentionally ignored. This prevents a token belonging to one workspace (e.g. your work Slack export) from silently being used when you ran `--profile personal`. When that situation is detected, `NotFoundError` is raised with the exact remediation steps.

### Global profile inheritance

Modeled after `git config --global`. The `global:` section in `~/.config/slack-status-cli/config.yml` defines defaults inherited by every profile; profile-level keys win on collision.

```yaml
global:
  oauth:
    client_id: "1234567890.0987654321"
    client_secret_ref: "dl://slack-status-cli/oauth-client-secret"
  storage_backend: dashlane

profiles:
  work:
    token_ref: "dl://slack-status-cli/work-token"
  personal:
    token_ref: "dl://slack-status-cli/personal-token"
    storage_backend: keychain     # overrides global
```

`SlackStatusCli::Tokens::Queries::MergedSettings` deep-merges the two before any backend lookup, so a backend never sees the unmerged form. The OAuth `client_id` and `client_secret_ref` belong in `global` because they're properties of the Slack App (one App per repo), not of an individual workspace token.

## Why no `slack` CLI for token generation

Slack's official `slack` CLI ([api.slack.com/automation/cli](https://api.slack.com/automation/cli)) targets the next-gen automation platform — Deno-based Functions and Workflows. The tokens it can mint are app-level and bot-level (`xoxa-`, `xoxb-`), not the `xoxp-` **user token** with `users.profile:write` scope that this CLI needs.

User tokens are gated behind the OAuth install flow. The realistic automated path is what `setup` does:

1. User creates a Slack App once (one-click via the shipped manifest).
2. `setup` boots a one-shot WEBrick listener on `localhost:53682` (loopback only — both `127.0.0.1` and `::1`).
3. Browser opens `https://slack.com/oauth/v2/authorize?...&user_scope=users.profile:write&state=...`.
4. Slack redirects to `http://localhost:53682/callback?code=...&state=...`.
5. `setup` POSTs to `oauth.v2.access` with HTTP Basic (client_id:client_secret).
6. The returned `authed_user.access_token` is the `xoxp-` token. It's persisted via the selected backend.

Community tools that "auto-extract" `xoxc`/`xoxd` from the Slack web client exist but use undocumented tokens incompatible with `users.profile.set`. They break frequently. We don't support them.

## Why WEBrick

WEBrick is the simplest HTTP server that ships with Ruby and was removed from stdlib in Ruby 3.0. The OAuth install flow needs exactly one short-lived `/callback` handler — no need for Puma/Sinatra/etc. Pinning the `webrick` gem (`~> 1.8`) in the `Gemfile` keeps the dep surface tiny.

## Conventions for `docs/`

- Plain GitHub-rendered markdown — no MkDocs/Docusaurus build step. The repo is small enough that a static site generator would be overkill.
- Cross-links are relative (`[setup.md](setup.md)`, `[../slack_status.rb](../slack_status.rb)`) so the repo browses correctly on GitHub and on a local clone.
- Every `docs/*.md` opens with an H1 matching the README link text and a one-sentence purpose blurb, so search results are self-describing.

## Future work

- **Real ticket tracker.** The workspace rule mandates `em/PI-XXX_*` branch names, but `PI-XXX` is currently synthetic. Wiring Linear / GitHub Issues would let the PR template link real tickets.
- **Windows / Linux Keychain equivalents.** `KeychainBackend` currently shells out to macOS `security`. `secret-tool` (libsecret) on Linux and `wincred` on Windows would be drop-in replacements once the tool grows past macOS.
- **Scheduled rotation.** Today `setup --rotate` is on-demand. A cron-friendly `slack_status.rb rotate` that revokes the old token via `auth.revoke` and stores the new one would round out the lifecycle.
- **Multi-org Dashlane.** `dcli` supports team vaults via `DASHLANE_TEAM_DEVICE_CREDENTIALS`; the current backend is personal-vault only.
- **Optional MkDocs / Docusaurus build for `docs/`** if the docs keep growing. Right now plain markdown is fine; revisit if we cross ~15 docs files or add diagrams that need a custom renderer.
