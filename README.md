# slack-status-cli

A Ruby-based CLI tool for updating your Slack status with mythological flair and Apple Music integration ✨🎵

## Features

- **Mythological Status**: Set random mythological beast emojis (wolf, lion, phoenix, fox, butterfly)
- **Preset Modes**: Quick lunch and break statuses with auto-expiration
- **Apple Music Integration**: Display currently playing track with mythological creatures
- **Custom Status**: Set any custom message and emoji combination
- **Auto-expiration**: Built-in support for temporary statuses
- **Graceful Shutdown**: Clean status clearing on exit

## 🛠️ Setup

1. **Get your Slack user token (`xoxp-...`)**
   - Create a Slack app at https://api.slack.com/apps
   - Add the scope `users.profile:write`
   - Install the app to your workspace and grab the token

2. **Set it as an environment variable**:

   ```bash
   export SLACK_SECRET_TOKEN=xoxp-...
   ```

3. **Install `nowplaying-cli`** (required for `musical_myth`):

   ```bash
   brew install nowplaying-cli
   ```

   This is what `musical_myth` reads to pick up the currently playing track. If it's missing, the loop falls back to AppleScript against the native `Music.app`; if both fail, the status text falls back to `🔇 sound of silence`.

---

## 🔥 Usage

```bash
ruby slack_status.rb                        # Sets a random mythological beast emoji
ruby slack_status.rb myth                   # Sets a random mythological beast emoji
ruby slack_status.rb lunch                  # Sets lunch status (expires in 1 hour)
ruby slack_status.rb break                  # Sets break status (expires in 30 minutes)
ruby slack_status.rb clear                  # Clears the status
ruby slack_status.rb musical_myth           # Continuously updates with the currently playing track
ruby slack_status.rb custom "Custom message" ":fire:" [expiration_seconds]  # Custom status
```

> Reserved first-arg modes are `myth`, `lunch`, `break`, `clear`, and `musical_myth`. Any other value (`custom`, `focus`, `""`, etc.) is treated as a custom status and the remaining args (`text`, `emoji`, `expiration_seconds`) take over.

### Musical Myth Mode

The `musical_myth` mode runs continuously, polling the current track and reflecting its **playback state** in your Slack status:

- The `:music:` emoji stays as the Slack status emoji in every state (continuity).
- **Playing**: status text is a random mythological creature emoji plus the currently playing track (song, artist, album), e.g. `♪♬  :phoenix_ash: Bohemian Rhapsody - Queen (A Night at the Opera)`.
- **Paused**: status text becomes a myth-themed intermission line, e.g. `⏸️ :fox_face: the oracle is thinking… — Bohemian Rhapsody - Queen`. The phrase rotates through a pool (`PAUSED_PHRASES` in [`lib/slack.rb`](lib/slack.rb)) and only the title + artist are shown so longer track names fit under Slack's 100-grapheme limit.
- **Nothing playing**: status text falls back to `🔇 sound of silence`.

Press `Ctrl+C` to stop and automatically clear your status. If a previous run leaves a stale status behind, you can wipe it with `ruby slack_status.rb clear`.

#### Adaptive refresh cadence

The loop picks its sleep interval based on the last observed state, so paused → playing transitions feel snappy without busy-polling when nothing is happening:

| State    | Sleep | Why |
|----------|-------|-----|
| Playing  | 120 s | Track titles change slowly; preserve Slack rate-limit budget. |
| Paused   | 30 s  | Quick switch back to the playing line when you hit play. |
| Silent   | 120 s | Nothing to refresh; long nap. |
| Unknown (tick errored) | 120 s | Conservative fallback during transient failures. |

Constants live at the top of [`lib/slack.rb`](lib/slack.rb) (`PLAYING_SLEEP`, `PAUSED_SLEEP`, `SILENT_SLEEP`) for easy tuning. Even the snappiest cadence (30 s) is well under Slack's Tier 3 budget for `users.profile.set` (~50 req/min).

#### How the current track is detected

`musical_myth` reads the track from macOS's system-wide "Now Playing" source via [`nowplaying-cli`](https://github.com/kirtan-shah/nowplaying-cli). That covers anything the OS treats as the active media source: the native `Music.app`, Spotify desktop, `music.apple.com` in any browser, QuickTime Player, Podcasts.app, and most browser tabs that integrate with the Media Session API (YouTube, SoundCloud, etc.).

Playback state comes from the `playbackRate` property (mapped to the private `kMRMediaRemoteNowPlayingInfoPlaybackRate` field):

- `playbackRate > 0` → **playing**
- `playbackRate == 0` with a known title → **paused**
- Missing `playbackRate` with a known title → assumed **playing** (back-compat for sources that omit the field)
- No title → **silent**

If `nowplaying-cli` is missing or returns no track, the loop silently falls back to AppleScript against the native `Music.app`. The fallback reads `player state` so it can distinguish `playing`, `paused`, and `stopped` the same way. If that also returns nothing, the status text falls back to `🔇 sound of silence`.

Caveat: `nowplaying-cli` relies on the private `MediaRemote` framework. On modern macOS (14.4+) Apple has tightened access to this API. The maintained `nowplaying-cli` build works as of writing, but if Apple ever closes it further the primary path will return empty and the AppleScript fallback (native `Music.app` only) is what you'll be left with.

---

## 💡 Examples

```bash
# Custom status with fire emoji
ruby slack_status.rb custom "Deep in the code" ":fire:"

# Custom status that expires in 1 hour (3600 seconds)
ruby slack_status.rb custom "In a meeting" ":speech_balloon:" 3600

# Heads-down / focus block for 2 hours
ruby slack_status.rb custom "Heads down — focusing" ":no_entry:" 7200

# Out of office for the rest of the workday (8 hours)
ruby slack_status.rb custom "OOO — back tomorrow" ":palm_tree:" 28800

# Doctor / personal appointment for 1 hour
ruby slack_status.rb custom "Personal appointment" ":hospital:" 3600

# Commute for 30 minutes
ruby slack_status.rb custom "Commuting" ":bike:" 1800

# Pairing session for 1 hour
ruby slack_status.rb custom "Pairing" ":handshake:" 3600

# Start music tracking (runs until stopped)
ruby slack_status.rb musical_myth

# Run music tracking in the background and stop it cleanly later
ruby slack_status.rb musical_myth &
kill %1   # TERM is trapped, so the status is cleared on exit

# Debug music detection without touching Slack
ruby lib/music.rb
```

---

## 📁 Project Structure

```
.
├── slack_status.rb        # Main CLI script
├── lib/
│   ├── slack.rb          # Slack API integration
│   └── music.rb          # Now-playing detection (nowplaying-cli + AppleScript fallback)
└── README.md
```

---

## Requirements

- Ruby
- macOS (for Apple Music integration)
- Slack workspace with appropriate permissions

---

## ⚠️ Notes & Gotchas

- **Status text is silently truncated to 100 graphemes** with an ellipsis (`…`). Long song titles or custom messages will be clipped at the last whitespace inside the limit.
- **Track detection runs on every invocation, not just `musical_myth`.** The internal mode map is built eagerly, so `nowplaying-cli` (and the AppleScript fallback if needed) is shelled out even for `myth`, `lunch`, `break`, and `clear`. macOS is effectively required for any mode; on non-macOS systems the call fails and the script keeps going.
- **Missing or invalid token → `not_authed`.** `SLACK_SECRET_TOKEN` is read once at load time with no validation. If it's unset or wrong, the request still fires and Slack responds with `❌ Failed to update status: not_authed`. Double-check `echo $SLACK_SECRET_TOKEN` before debugging further.
- **Paused state depends on `playbackRate`.** A handful of media sources omit the field; for those, `musical_myth` will keep showing the playing line even while paused. Spot-check your main players (Spotify desktop, Music.app, browser tabs) the first time you run it.
- **`clear` is your escape hatch.** If `musical_myth` (or any expiring status) leaves something stuck, run `ruby slack_status.rb clear` to wipe it.

---

## 📜 License

Intended to be MIT-licensed, but no `LICENSE` file is committed to the repo yet — treat the code as "all rights reserved" until one is added.
