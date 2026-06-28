# Security

How `slack-status-cli` keeps your Slack user token safe at rest, in transit, and in logs.

## Recommended storage order

| Backend | Strengths | Weaknesses |
|---|---|---|
| `dashlane` (default) | Encrypted vault; sync across devices; same store as the rest of your credentials | One-time `dcli sync` unlock; manual write step (Dashlane personal has no unattended write API) |
| `keychain` | macOS-native; encrypted; programmatic read + write via `security`; survives across shells | macOS only |
| `file` | Simple; works in any tool; explicit | Plaintext on disk; relies on filesystem perms (we enforce `0600`) |
| `env` | Easy to script; convenient for CI | Leaks into process listings (`ps`), shell history, child processes |

The resolver walks `--token > SLACK_STATUS_TOKEN_<PROFILE> > config-driven backend (profile -> global) > SLACK_SECRET_TOKEN (legacy, default profile only)`. Diagram and full description in [docs/architecture.md](architecture.md#token-resolver). The legacy env var is **never** used for an explicitly named or explicitly configured profile, to prevent cross-workspace token leakage.

## Dashlane integration

`slack-status-cli` shells out to `dcli read dl://<title>` to fetch the token. Setup:

```bash
brew install dashlane/tap/dashlane-cli       # macOS / Linux; Windows + manual installs: cli.dashlane.com/install
dcli sync                                    # one-time interactive unlock
ruby slack_status.rb setup --profile personal --backend dashlane
```

The `setup` command can't write to Dashlane personal directly (no unattended write API), so it prints a one-time block with the token + the exact secure-note title to create. Once the note is saved:

```bash
dcli read dl://slack-status-cli/personal-token   # should print the token to stdout
ruby slack_status.rb doctor --profile personal   # validates against auth.test
```

For one-shot invocations from scripts you can bypass the resolver entirely:

```bash
dcli exec -- ruby slack_status.rb --token "$DASHLANE_TOKEN" myth
```

If `dcli` isn't installed or the vault is locked, the resolver falls through to the next backend the profile is configured for (no silent fallback — the chain is explicit in [docs/architecture.md](architecture.md#token-resolver)).

## Security strategies (what the code enforces)

- **Default to a secret manager, not env vars.** The `setup` flow recommends Dashlane > Keychain > file > env in that order.
- **Scope minimization.** The shipped manifest ([`docs/slack-app-manifest.yml`](slack-app-manifest.yml)) requests only `users.profile:write` as a user scope. No bot scopes, no `chat:write`.
- **Token-at-rest only.** `~/.config/slack-status-cli/config.yml` never stores the token — it only stores the *reference* (which backend + key/title) and the OAuth `client_id`. `client_secret` is read via `client_secret_ref` (a `dl://…`, `env:VAR`, or `file:/path` URI) or prompted with echo off.
- **`FileBackend` perm-guard.** Writing a token via `file` backend chmods the file `0600`. Reading refuses (and falls through) if `(stat.mode & 0o077) != 0`, so a misconfigured permission can't silently leak the secret.
- **Validate at setup + on demand.** `doctor` calls `auth.test` to fail fast with a useful error code (`not_authed`, `missing_scope`, etc.) instead of letting `users.profile.set` return cryptic errors later.
- **No token in logs.** `--verbose` prints the *source* of the resolved token (`resolved from dashlane:dl://slack-status-cli/work`) but never the value. Any caught exception passes through `CliPrompt.scrub_secrets` which replaces `xox[a-z]-…` patterns with `xox?-…XXXX`.
- **State + loopback guard on OAuth.** The helper generates a 16-byte hex `state`, includes it in the authorize URL, and rejects callbacks where it doesn't match. The WEBrick listener binds to `localhost` loopback only — both `127.0.0.1` and `::1`, never `0.0.0.0` — so other hosts on the LAN can't race the callback.
- **Per-profile isolation.** Each profile has its own backend entry; compromising one workspace's token doesn't leak others. Profiles can mix backends (work in Dashlane, personal in Keychain).
- **One-shot listener.** WEBrick shuts down after the first successful callback (or a 2-minute timeout). Reduces the window for a malicious local process to hit `/callback`.

## Threat model checklist

| Threat | Mitigation |
|---|---|
| Shoulder-surf at install time | Client Secret prompt disables terminal echo; token is printed once with a redacted preview |
| Shell history (`ctrl-r`) leaks | Don't pass `--token` or `--client-secret` on the command line; use prompts or `dcli exec` |
| `ps`/`top` shows args | Same — secret-bearing CLI flags are visible in process listings |
| Lost laptop | Dashlane / Keychain are encrypted at rest; file backend relies on FileVault |
| Compromised single profile | Per-profile tokens limit blast radius; `auth.revoke` + `setup --rotate` to rebuild |
| Malicious local process | OAuth listener binds loopback only (`localhost`); `state` validates the callback origin; one-shot listener |

## Rotation

```bash
ruby slack_status.rb setup --profile personal --rotate
```

That re-runs OAuth and overwrites the stored token. To also invalidate the old token server-side, hit `auth.revoke`:

```bash
curl -s -H "Authorization: Bearer xoxp-OLD-TOKEN" https://slack.com/api/auth.revoke | jq .
```

If you suspect a leak, rotate first (so the new token is available), then revoke the old one.
