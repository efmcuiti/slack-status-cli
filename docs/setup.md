# Setup

End-to-end walkthrough: install the prerequisites, create the Slack App from the shipped manifest, run the OAuth install flow (`setup`), and verify with `doctor`.

## Prerequisites

| Tool | Required? | Install one-liner |
|---|---|---|
| **Ruby `~> 3.0`** | Required | `brew install ruby@3` (or `mise install ruby@3` / `rbenv install 3.x`) |
| **Bundler** | Required | `gem install bundler` (then `bundle install` in this repo to pull `webrick`) |
| **`nowplaying-cli`** | Required for `musical_myth` | `brew install nowplaying-cli` |
| **Dashlane CLI (`dcli`)** | Recommended (primary backend) | `brew install dashlane/tap/dashlane-cli`, then one-time `dcli sync`; verify with `dcli --version`. Other platforms / install methods: [`cli.dashlane.com/install`](https://cli.dashlane.com/install). |
| **Slack CLI (`slack`)** | **Optional** | `brew install slackapi/slack-cli/slack-cli`. **Not required** for `slack-status-cli` — it's only useful for managing your Slack App from the terminal. See [api.slack.com/automation/cli](https://api.slack.com/automation/cli) and the [architecture note on why this CLI can't generate user tokens](architecture.md#why-no-slack-cli-for-token-generation). |
| **macOS Keychain (`security`)** | Preinstalled on macOS | No action needed. Listed for completeness as a backup backend. |

## 1. Create the Slack App from the manifest

1. Open <https://api.slack.com/apps?new_app=1>.
2. Pick **"From a manifest"** and select your workspace.
3. Paste the contents of [`docs/slack-app-manifest.yml`](slack-app-manifest.yml) and confirm.
4. Open **Basic Information** in the new app. Copy the **Client ID** and **Client Secret**.

The manifest pre-fills:

- `user_scope: users.profile:write` — required to edit your own status.
- `user_scope: emoji:read` — required by [`migrate-emojis`](usage.md#migrate-emojis); not used by any status mode. Listing/downloading only — never writes.
- `redirect_url: http://localhost:53682/callback` — matches what the `setup` listener listens on.

> **Upgrading existing installs.** If your app was created before `emoji:read` was added to the manifest, the existing token won't have it. Re-run `setup --profile <name> --rotate` to re-OAuth and pick up the new scope (the manifest itself updates automatically when you "Update from manifest" in the Slack App settings UI).

> **Multi-workspace setups: one app per workspace.** Slack apps default to "internal" (single-workspace) install. Enabling **Distribution** to install one app across multiple workspaces requires an **HTTPS** redirect URL, which loopback (`http://localhost`) doesn't satisfy. The simplest workaround is to create **one Slack App per workspace** from the same manifest. Each app stays internal and keeps `http://localhost:53682/callback`. `slack-status-cli` handles this by storing `client_id` per profile (see [Multi-workspace setup](#multi-workspace-setup) below).

## 2. (One time) Set global defaults

Stash the OAuth client ID + your preferred storage backend so every profile inherits them:

```bash
ruby slack_status.rb setup --global --client-id <YOUR_CLIENT_ID> --backend dashlane
```

`--backend` is one of `dashlane` (recommended), `keychain`, `file`, or `env`. See [Security](security.md) for trade-offs.

This writes `~/.config/slack-status-cli/config.yml` with permissions `0600`. The client secret is **not** stored in the file — provide it interactively per setup, or point `global.oauth.client_secret_ref` at a Dashlane URI / env var.

If you'll have **more than one Slack App** (one per workspace — recommended for multi-workspace setups), it's fine to skip Step 2 entirely. Profile-level `client_id`s persist automatically in Step 3.

## 3. Run setup for each profile

```bash
ruby slack_status.rb setup --profile personal
```

The script walks you through 4 steps with emoji progress markers. The first time you run it (no cached `client_id`), Step 1 prints a `✋` block telling you exactly how to create the Slack App from the manifest and where to copy the credentials before it prompts for them. Subsequent profile setups just ask whether to reuse the cached values.

### First-time output (no global config yet)

```
🔧 Step 1/4: Slack App configuration

✋ Manual step required
   Where to find your Client ID + Client Secret:
     1) Open https://api.slack.com/apps?new_app=1
     2) Pick "From a manifest", then pick your workspace.
     3) Paste the contents of docs/slack-app-manifest.yml and confirm.
     4) On the new app's "Basic Information" page, scroll to "App Credentials":
        - Client ID looks like 1234567890123.0987654321098
        - Click "Show" next to Client Secret to reveal it.
     5) The manifest pre-fills the OAuth redirect URL; double-check it under
        "OAuth & Permissions" → "Redirect URLs": http://localhost:53682/callback

   Press Enter once you're done… _
Enter Client ID (from Basic Information): 1234567890123.0987654321098
Enter Client Secret (from Basic Information; input hidden): ********

🔧 Step 2/4: Choose a token storage backend
   Use the default backend `dashlane`? [Y/n]
✅ Backend: dashlane

🔧 Step 3/4: OAuth install
🌐 Opening https://slack.com/oauth/v2/authorize?… in your browser.
   Listening on http://localhost:53682/callback (2 min timeout)…
✅ Received authorization code; exchanging for user token…
✅ Got xoxp-…XXXX (scope=users.profile:write, team=Acme)

🔧 Step 4/4: Persist the token
🔐 Wrote token to dashlane:dl://slack-status-cli/personal-token.
✅ Setup complete. Verify with: ruby slack_status.rb doctor --profile personal
```

### Returning user (cached global config)

```
🔧 Step 1/4: Slack App configuration
   Found global client_id ending in …4321. Reuse it? [Y/n]
✅ Using global client_id ending in …4321.
Enter Client Secret (from Basic Information; input hidden): ********
... (steps 2-4 as above)
```

Conventions baked into the prompts:

- `[Y/n]` / `[y/N]` defaults follow the bash idiom — Enter accepts the capitalized option.
- The Client Secret prompt disables terminal echo (`io.noecho`); the script never echoes it back in full. Confirmation lines truncate to the last 4 chars (`…1234`).
- `✋` blocks pause for an Enter press whenever the script needs you to act outside the terminal.
- `--non-interactive` skips every prompt and fails fast if a required value is missing — useful for scripted reruns.
- `--rotate` re-runs OAuth and overwrites the existing token for the profile.

## 4. Verify

```bash
ruby slack_status.rb doctor --profile personal
```

Expected output (token redacted):

```
   source : dashlane:dl://slack-status-cli/personal-token
   profile: personal
   token  : xoxp-…XXXX
✅ auth.test ok — workspace=Acme user=eric url=https://acme.slack.com/
```

Failure modes get specific hints (re-run setup, missing scope, deactivated account, etc.). See [Troubleshooting](troubleshooting.md).

## Profile management

- Active profile: `--profile <name>` flag, `SLACK_STATUS_PROFILE` env var, or `"default"` when neither is set.
- Profile-scoped env var: `SLACK_STATUS_TOKEN_<PROFILE>` (e.g. `SLACK_STATUS_TOKEN_WORK`) overrides config-based resolution. Useful for CI.
- List profiles: `ruby slack_status.rb profiles list`.
- Inspect / change config: `ruby slack_status.rb config get global.storage_backend`, `config set profiles.work.storage_backend keychain`.
- The config file is at `~/.config/slack-status-cli/config.yml` (override with `--config PATH`).

## Multi-workspace setup

If you belong to more than one Slack workspace and want to flip your status between them, the recommended path is **one Slack App per workspace**. Each app stays internal (no Distribution toggle, no HTTPS redirect requirement), and each profile pins the right app's credentials.

1. **Create the first app** by following Step 1 above against your first workspace. Copy that Client ID/Secret.
2. **Create the second app** by repeating Step 1 against your second workspace. Same manifest, different workspace, different Client ID/Secret.
3. **Run setup once per profile**, passing the matching Client ID:

   ```bash
   ruby slack_status.rb setup --profile negotiatus --client-id <AAA>
   ruby slack_status.rb setup --profile personal   --client-id <BBB>
   ```

   At Step 4 (Persist the token), `slack-status-cli` writes the per-profile `client_id` to `profiles.<name>.oauth.client_id` **only when it differs from the global default**, so the config stays tidy:

   ```yaml
   global:
     oauth:
       client_id: <AAA>          # also used by `negotiatus`, no per-profile entry needed
     storage_backend: dashlane

   profiles:
     negotiatus:
       storage_backend: dashlane # inherits client_id from global
     personal:
       storage_backend: dashlane
       oauth:
         client_id: <BBB>        # overrides global because it diverges
   ```

4. **Switch workspaces** by switching profiles:

   ```bash
   ruby slack_status.rb --profile negotiatus lunch
   ruby slack_status.rb --profile personal   musical_myth
   ruby slack_status.rb doctor --profile personal
   # ✅ auth.test ok — workspace=efmcuiti user=eric url=https://efmcuiti.slack.com/
   ```

`doctor` calls `auth.test` against whichever workspace the resolved token is bound to, so it's a one-liner sanity check after every setup or rotate.

See [docs/usage.md](usage.md) for the full flag/command reference, and [docs/security.md](security.md) for token storage trade-offs.
