# slack-status-cli

A Ruby-based CLI for updating your Slack status with mythological flair and Apple Music integration ✨🎵

## Features

- **Mythological status emojis** with preset modes (`myth`, `lunch`, `break`, `clear`) — see [docs/usage.md](docs/usage.md).
- **Apple Music / now-playing integration** with adaptive refresh cadence — see [docs/musical-myth.md](docs/musical-myth.md).
- **Multi-profile token management** with Dashlane / Keychain / file / env backends and git-style global defaults — see [docs/security.md](docs/security.md).
- **One-command OAuth setup** against a manifest-defined Slack App — see [docs/setup.md](docs/setup.md).
- **`doctor` mode** that validates the resolved token via `auth.test` and decodes Slack-side errors — see [docs/troubleshooting.md](docs/troubleshooting.md).

## Quickstart

```bash
bundle install
ruby slack_status.rb setup --profile personal   # walks you through OAuth + storage
ruby slack_status.rb doctor --profile personal  # validates the token
ruby slack_status.rb myth                       # flex a random mythological beast
```

Full prerequisites (Ruby 3, `nowplaying-cli`, optional `dcli` for Dashlane) live in [docs/setup.md](docs/setup.md).

## Documentation

- [Setup](docs/setup.md) — Slack App + manifest, OAuth install flow, profiles, prerequisites.
- [Security](docs/security.md) — token storage strategies, Dashlane integration, threat model, rotation.
- [Usage](docs/usage.md) — full CLI reference: flags, modes, subcommands, expiration semantics.
- [Musical Myth Mode](docs/musical-myth.md) — now-playing detection, adaptive cadence, fallbacks, caveats.
- [Examples](docs/examples.md) — copy-pasteable invocations.
- [Troubleshooting](docs/troubleshooting.md) — notes, gotchas, `doctor` workflow, common Slack errors.
- [Architecture](docs/architecture.md) — project structure, token-resolver design, future work.
- [Project workflow](docs/project-workflow.md) — GitHub Project conventions: labels as canonical metadata, Status field, agent housekeeping steps, useful filters.

## Requirements

- Ruby `~> 3.0` and Bundler.
- macOS (for Apple Music integration and the `security`-backed Keychain backend).
- A Slack workspace with permission to install a personal app. See [docs/setup.md](docs/setup.md).

## Project conventions

Business logic lives in small, single-purpose **Callable** objects under `lib/slack_status_cli/<pod>/`, organized into pods (`slack`, `music`, `tokens`, `oauth`, `cli`, `emoji_migration`):

- **`queries/`** read and return a value; **`commands/`** perform a side effect. Each exposes one public entry point — `.call` — via `extend Callable`.
- Constructor keywords are held behind a **private `attr_reader`** and read through the readers (never a raw `@ivar` outside `initialize`), so inputs stay named, read-only, and easy to stub.
- Each pod owns its **`Errors`** vocabulary (`Error < StandardError` + specific subclasses) and raises those rather than bare `RuntimeError`.
- **RSpec-first:** specs mirror the `lib/` tree under `spec/` (`lib/slack_status_cli/foo/bar.rb` → `spec/slack_status_cli/foo/bar_spec.rb`). Orchestrators inject their collaborators as kwargs so specs pass fakes.

See [docs/architecture.md](docs/architecture.md) for the full Callable conventions and pod layout.

## License

Intended to be MIT-licensed, but no `LICENSE` file is committed to the repo yet — treat the code as "all rights reserved" until one is added.
