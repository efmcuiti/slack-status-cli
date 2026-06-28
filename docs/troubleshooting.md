# Troubleshooting

Notes, gotchas, and a decoder for the Slack-side error codes you may see.

## First step: run `doctor`

```bash
ruby slack_status.rb doctor --profile <name>
```

`doctor` resolves the token, prints the source it came from (without ever logging the value), and calls Slack's `auth.test`. Every failure mode prints a specific recovery hint. If `doctor` is happy and a status command still fails, the bug is almost certainly elsewhere (track detection, status formatting, etc.).

## Slack error decoder

| `error` field | What it means | What to do |
|---|---|---|
| `not_authed` | No token sent (or empty bearer). | The resolver returned an empty string. Check `--verbose` to see which source was used; `setup --profile <name> --rotate` to refresh. |
| `invalid_auth` | Token sent but Slack doesn't recognize it. | Token is wrong / corrupted. `setup --profile <name> --rotate`. |
| `token_revoked` | Token was valid; you revoked it (intentionally or via `auth.revoke`). | `setup --profile <name> --rotate`. |
| `missing_scope` | Token lacks `users.profile:write`. | Re-create the Slack App from [`slack-app-manifest.yml`](slack-app-manifest.yml), or edit the existing app's OAuth & Permissions page to add the user scope, then `setup --profile <name> --rotate`. |
| `account_inactive` | The Slack user owning this token is deactivated. | Use a different account. |
| `rate_limited` | Slack is throttling. | Wait and retry. `musical_myth`'s adaptive cadence is tuned for the Tier 3 budget; if you hit this regularly something else is consuming the budget. |

## Gotchas

- **Status text is silently truncated to 100 graphemes** with an ellipsis (`…`). Long song titles or custom messages will be clipped at the last whitespace inside the limit.
- **Track detection runs on every invocation, not just `musical_myth`.** The internal mode map is built eagerly, so `nowplaying-cli` (and the AppleScript fallback if needed) is shelled out even for `myth`, `lunch`, `break`, and `clear`. macOS is effectively required for any mode; on non-macOS systems the call fails and the script keeps going.
- **Paused state depends on `playbackRate`.** A handful of media sources omit the field; for those, `musical_myth` will keep showing the playing line even while paused. Spot-check your main players (Spotify desktop, Music.app, browser tabs) the first time you run it.
- **`clear` is your escape hatch.** If `musical_myth` (or any expiring status) leaves something stuck, run `ruby slack_status.rb clear` to wipe it.
- **`FileBackend` refuses world-readable files.** If you `chmod 644` your token file the resolver warns and skips it (`refusing to read … permissions 644 are too open (chmod 600)`). Fix with `chmod 600`.
- **Dashlane writes are manual.** The `setup` flow can't programmatically add a secure note to Dashlane personal vaults. It prints the title + token once with instructions; copy them into Dashlane, then `doctor` confirms the round-trip.
- **`webrick` is no longer in stdlib.** As of Ruby 3.0 you need `bundle install` (the `Gemfile` pins `webrick`) for `setup` to work.

## Logs and redaction

- `--verbose` prints the **source** of the resolved token to stderr (e.g. `[slack-status-cli] token resolved from dashlane:dl://slack-status-cli/work (profile=work)`). It never prints the value.
- Any caught exception is passed through `CliPrompt.scrub_secrets`, which substitutes `xox[a-z]-…` patterns with `xox?-…XXXX`. If you spot a real token in any log line, that's a bug — please file an issue with the trace.

## OAuth install (`setup`) getting stuck

- The listener binds `127.0.0.1:53682`. If another process is using that port, `setup` fails with `Port 53682 is already in use on 127.0.0.1.` (raised as `PortBusy`, with a `kill $(lsof …)` remediation). Kill the squatter or change the port (currently hardcoded at the `run_setup` call site in [`../slack_status.rb`](../slack_status.rb), passed to [`Oauth::Commands::WaitForCallback`](../lib/slack_status_cli/oauth/commands/wait_for_callback.rb)).
- The listener has a 2-minute timeout. If your browser is slow or you closed the tab, re-run `setup --rotate`.
- State mismatch (CSRF guard) means Slack returned a different `state` than we sent. Re-run; if it persists, your browser may be replaying an old authorize URL.
