# Architecture

Project layout, the token-resolver design, and a few "we considered X" notes so future contributors don't relitigate the obvious questions.

## Project structure

```
.
├── slack_status.rb              # CLI entry point: OptionParser + subcommand dispatch
├── Gemfile                      # Minimal: webrick (extracted from stdlib in Ruby 3.0)
├── lib/
│   ├── slack_status_cli.rb      # Root namespace + autoload entry point for the Callable pods
│   ├── slack_status_cli/        # Callable pods: slack/, music/, tokens/, oauth/ (+ callable.rb, secret_scrubber.rb)
│   ├── cli_prompt.rb            # Interactive UX helpers ([Y/n], secret input, emoji progress, scrub_secrets)
│   └── emoji_migrator.rb        # Emoji export helper (migrate-emojis subcommand)
├── docs/
│   ├── setup.md                 # Slack App + manifest, prerequisites, setup walkthrough
│   ├── security.md              # Token storage strategies, Dashlane, threat model, rotation
│   ├── usage.md                 # Full CLI reference: flags, modes, subcommands
│   ├── musical-myth.md          # Now-playing detection deep-dive
│   ├── examples.md              # Copy-pasteable invocations
│   ├── troubleshooting.md       # Notes, gotchas, Slack error decoder
│   ├── architecture.md          # This file
│   └── slack-app-manifest.yml   # Slack App manifest (paste at app creation time)
└── README.md
```

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

WEBrick is the simplest HTTP server that ships with Ruby and was removed from stdlib in Ruby 3.0. The OAuth helper needs exactly one short-lived `/callback` handler — no need for Puma/Sinatra/etc. Pinning the `webrick` gem (`~> 1.8`) in the `Gemfile` keeps the dep surface tiny.

## Conventions for `docs/`

- Plain GitHub-rendered markdown — no MkDocs/Docusaurus build step. The repo is small enough that a static site generator would be overkill.
- Cross-links are relative (`[setup.md](setup.md)`, `[../lib/slack.rb](../lib/slack.rb)`) so the repo browses correctly on GitHub and on a local clone.
- Every `docs/*.md` opens with an H1 matching the README link text and a one-sentence purpose blurb, so search results are self-describing.

## Future work

- **Broaden spec coverage.** The Tokens pod callables (`ResolveToken`, the backends, `MergedSettings`) have specs; the remaining CLI dispatcher in `slack_status.rb` is covered only by manual smoke tests until the Cli pod extraction lands.
- **Real ticket tracker.** The workspace rule mandates `em/PI-XXX_*` branch names, but `PI-XXX` is currently synthetic. Wiring Linear / GitHub Issues would let the PR template link real tickets.
- **Windows / Linux Keychain equivalents.** `KeychainBackend` currently shells out to macOS `security`. `secret-tool` (libsecret) on Linux and `wincred` on Windows would be drop-in replacements once the tool grows past macOS.
- **Scheduled rotation.** Today `setup --rotate` is on-demand. A cron-friendly `slack_status.rb rotate` that revokes the old token via `auth.revoke` and stores the new one would round out the lifecycle.
- **Multi-org Dashlane.** `dcli` supports team vaults via `DASHLANE_TEAM_DEVICE_CREDENTIALS`; the current backend is personal-vault only.
- **Optional MkDocs / Docusaurus build for `docs/`** if the docs keep growing. Right now plain markdown is fine; revisit if we cross ~15 docs files or add diagrams that need a custom renderer.
