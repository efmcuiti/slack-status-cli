# Usage

Full CLI reference for `slack_status.rb`. For installation + token setup see [Setup](setup.md); for end-to-end recipes see [Examples](examples.md).

## Invocation shape

```
ruby slack_status.rb [global flags] <command> [command args]
```

`<command>` is either:

- A **mode** (`myth`, `lunch`, `break`, `clear`, `musical_myth`, or any other value treated as `custom`), or
- A **subcommand** (`setup`, `doctor`, `config`, `profiles`, `migrate-emojis`).

Global flags must come **before** the command. Anything after the command is passed to that command.

## Global flags

| Flag | Description |
|---|---|
| `--profile NAME` | Profile name. Default: `$SLACK_STATUS_PROFILE` or `default`. |
| `--token TOKEN` | Use this token directly (highest precedence; bypasses the resolver). |
| `--config PATH` | Path to `config.yml`. Default: `~/.config/slack-status-cli/config.yml`. |
| `--verbose` | Print resolver's chosen token source to stderr. Source only — never the token. |
| `--non-interactive` | Fail fast instead of prompting (`setup` and `doctor` only). |
| `--rotate` | (setup) Overwrite an existing token instead of skipping. |
| `--global` | (setup) Configure global defaults; skip OAuth + profile-token persistence. |
| `--backend NAME` | (setup) Storage backend: `dashlane`, `keychain`, `file`, `env`. |
| `--client-id ID` | (setup) Slack App client_id (overrides `global.oauth.client_id`). |
| `--client-secret SECRET` | (setup) Slack App client_secret. **Prefer the interactive prompt** — CLI args leak into `ps` and shell history. |
| `--from PROFILE` | (migrate-emojis) Source profile to download emojis from. |
| `--to PROFILE` | (migrate-emojis) Destination profile; used to derive the workspace's emoji admin URL via `auth.test`. |
| `--out DIR` | (migrate-emojis) Output directory. Default: `./emoji-export-<from>-<YYYYMMDD-HHMMSS>`. |
| `--filter REGEX` | (migrate-emojis) Case-insensitive regex; only emoji whose name matches are downloaded. |
| `--no-open` | (migrate-emojis) Don't automatically open the destination admin URL in a browser. |
| `-h`, `--help` | Show the OptionParser banner and exit. |

## Status modes

All status modes resolve the token via the [precedence chain](architecture.md#token-resolver) and POST to `users.profile.set`.

```bash
ruby slack_status.rb [--profile NAME] [--token TOKEN] <mode> [text] [emoji] [expiration_seconds]
```

| Mode | Behavior |
|---|---|
| `myth` (default when no mode given) | Random mythological-beast emoji, no text. |
| `lunch` | Sets `:meat_on_bone:` + `"<myth_emoji> - Lunch time!"`, expires in 1 hour. |
| `break` | Sets `:coffee:` + `"<myth_emoji> Taking a break"`, expires in 30 min. |
| `clear` | Wipes status (`status_text=""`, `status_emoji=""`, `status_expiration=0`). |
| `musical_myth` | Runs forever; updates status with the currently playing track. See [Musical Myth Mode](musical-myth.md). |
| anything else (e.g. `custom`, `focus`, `""`) | Custom status. `text`, `emoji`, `expiration_seconds` from positional args. |

### Custom mode args

| Position | Name | Type | Notes |
|---|---|---|---|
| 1 | `text` | string | Status text. Silently truncated to 100 graphemes with `…`. |
| 2 | `emoji` | string | Slack-style code like `:fire:`. |
| 3 | `expiration_seconds` | duration | Relative to now: bare seconds (`3600`) or duration sugar (`30m`, `2h`) → `status_expiration = now + value`. Unrecognized/empty values are ignored (no expiration). |

The coercion lives in [`Slack::Builders::ExpirationSeconds`](../lib/slack_status_cli/slack/builders/expiration_seconds.rb). To set a **sticky** status (`status_expiration=0`, never expires), **omit** the argument or pass an unrecognized/empty value. Note a literal `0` is a valid bare-seconds input, so it resolves to `now` (immediate expiry) — not sticky.

## Subcommands

### `setup`

Configures a profile (or `--global` defaults). See [Setup](setup.md) for the canonical walkthrough.

```bash
ruby slack_status.rb setup [--global] [--profile NAME] [--rotate] [--non-interactive]
                           [--backend NAME] [--client-id ID] [--client-secret SECRET]
```

### `doctor`

Resolves the token for the active profile, calls `auth.test`, and prints the workspace/user + resolved source. Exits non-zero on failure.

```bash
ruby slack_status.rb doctor [--profile NAME] [--token TOKEN] [--verbose]
```

Output (token redacted):

```
   source : dashlane:dl://slack-status-cli/personal-token
   profile: personal
   token  : xoxp-…XXXX
✅ auth.test ok — workspace=Acme user=eric url=https://acme.slack.com/
```

### `config`

Read/write the YAML config file at `~/.config/slack-status-cli/config.yml` (or `--config PATH`).

```bash
ruby slack_status.rb config get <dotted.key>
ruby slack_status.rb config set <dotted.key> <value>
ruby slack_status.rb config path
```

- Dotted keys traverse nested hashes (`global.oauth.client_id`, `profiles.work.storage_backend`).
- `set` coerces booleans (`true`/`false`), `null`/`nil`, and integers; everything else is a string.
- `get` prints scalars as-is and hashes/arrays as pretty-printed JSON.
- Exits 1 on `get` for an unset key (so `if ... fi` works in shell scripts).

### `profiles`

```bash
ruby slack_status.rb profiles list
```

Lists every profile in `config.yml` with its effective storage backend (profile override or global default).

### `migrate-emojis`

Downloads every custom emoji image from a **source** workspace into a local directory so it can be bulk-uploaded to a **destination** workspace via Slack's emoji admin page. Read-only against the Slack API; the upload half is done by drag-and-drop in the web UI because Slack does not expose an emoji-upload API for non-Enterprise workspaces.

```bash
ruby slack_status.rb migrate-emojis --from <src-profile> [--to <dest-profile>] \
                                    [--out DIR] [--filter REGEX] [--no-open]
```

What it does:

1. Resolves the source profile's token and calls `emoji.list` (requires the `emoji:read` scope; declared in the shipped manifest).
2. Downloads each entry whose value is an HTTPS URL (concurrent, default 6 workers) into `<out>/<name>.<ext>`. Detected extension comes from the URL or, as a fallback, the first few magic bytes.
3. Writes `aliases.json` next to the images recording every `alias:<other>` entry. Aliases must be recreated by hand in the destination workspace (`Add Custom Emoji → Add Alias`).
4. If `--to PROFILE` is provided, resolves that profile's token, calls `auth.test` to derive `https://<team>.slack.com/customize/emoji`, prints it, and opens it in the default browser (unless `--no-open`).
5. Walks the user through the manual upload step with an inline checklist.

#### Required scope

Both source and destination profiles need the `emoji:read` user scope (the destination only needs it for the `auth.test` workspace lookup — `users.profile:write` would suffice if you skip `--to`). The current `docs/slack-app-manifest.yml` already includes it; tokens minted before that change need `setup --profile <name> --rotate` to re-OAuth with the new scope.

#### Examples

```bash
ruby slack_status.rb migrate-emojis --from work --to personal
ruby slack_status.rb migrate-emojis --from work --to personal --filter '^myth(o|ical)' --out ./mythpack
ruby slack_status.rb migrate-emojis --from work --no-open --out /tmp/emojis
```

#### What lands on disk

```text
emoji-export-work-20260521-153012/
├── phoenix_ash.png
├── party_parrot.gif
├── …
├── aliases.json     # { "alias_name": "real_emoji_name", ... }
└── skipped.json     # only written when some images failed to download
```

#### Why this isn't fully automated

Slack restricts custom-emoji upload to the workspace admin web UI for Standard/Pro/Free workspaces; only Enterprise Grid exposes `admin.emoji.add`. The alternative — undocumented browser-session (`xoxc-` + `d` cookie) calls used by tools like `lambtron/emojipacks` — is fragile and walks Slack's TOS edge, so `slack-status-cli` deliberately stops at "downloaded images + opens the admin page".

## Expiration semantics

`expiration_seconds` from positional args is coerced by [`Slack::Builders::ExpirationSeconds`](../lib/slack_status_cli/slack/builders/expiration_seconds.rb) and sent as `status_expiration`. Every recognized input is treated as a duration relative to now: a bare integer (`3600`) → `now + 3600`, and duration sugar (`30m`, `2h`) → `now + offset`. Anything unrecognized (or empty) becomes a sticky status (expiration `0`). Edge case: a literal `0` is a valid bare-seconds value, so it resolves to `now` (immediate expiry) — to get a sticky status, omit the argument entirely.

Slack itself doesn't expire `status_emoji`; the entire profile fields (`status_text`, `status_emoji`, `status_expiration`) get reset to empty/`0` at the timestamp you provide.
