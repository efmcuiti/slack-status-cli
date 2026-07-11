# Musical Myth Mode

Continuous now-playing → Slack status sync with mythological flair.

```bash
ruby slack_status.rb musical_myth
```

The loop runs continuously, polling the currently playing track and reflecting its **playback state** in your Slack status:

- The `:music:` emoji stays as the Slack status emoji in every state (continuity).
- **Playing**: status text is a random mythological creature emoji plus the currently playing track (song, artist, album), e.g. `♪♬  :phoenix_ash: Bohemian Rhapsody - Queen (A Night at the Opera)`.
- **Paused**: status text becomes a myth-themed intermission line, e.g. `⏸️ :fox_face: the oracle is thinking… — Bohemian Rhapsody - Queen`. The phrase rotates through a pool (`PAUSED_PHRASES` in [`../lib/slack_status_cli/slack/formatters/tune_text.rb`](../lib/slack_status_cli/slack/formatters/tune_text.rb)) and only the title + artist are shown so longer track names fit under Slack's 100-grapheme limit.
- **Nothing playing**: status text falls back to `🔇 sound of silence`.

Press `Ctrl+C` to stop and automatically clear your status. If a previous run leaves a stale status behind, you can wipe it with `ruby slack_status.rb clear`.

## Adaptive refresh cadence

The loop picks its sleep interval based on the last observed state, so paused → playing transitions feel snappy without busy-polling when nothing is happening:

| State    | Sleep | Why |
|----------|-------|-----|
| Playing  | 120 s | Track titles change slowly; preserve Slack rate-limit budget. |
| Paused   | 30 s  | Quick switch back to the playing line when you hit play. |
| Silent   | 120 s | Nothing to refresh; long nap. |
| Unknown (tick errored) | 120 s | Conservative fallback during transient failures. |

Constants live at the top of [`../lib/slack_status_cli/slack/formatters/next_interval.rb`](../lib/slack_status_cli/slack/formatters/next_interval.rb) (`PLAYING_SLEEP`, `PAUSED_SLEEP`, `SILENT_SLEEP`) for easy tuning. Even the snappiest cadence (30 s) is well under Slack's Tier 3 budget for `users.profile.set` (~50 req/min).

## How the current track is detected

`musical_myth` reads the track from macOS's system-wide "Now Playing" source via [`nowplaying-cli`](https://github.com/kirtan-shah/nowplaying-cli). That covers anything the OS treats as the active media source: the native `Music.app`, Spotify desktop, `music.apple.com` in any browser, QuickTime Player, Podcasts.app, and most browser tabs that integrate with the Media Session API (YouTube, SoundCloud, etc.).

Playback state comes from the `playbackRate` property (mapped to the private `kMRMediaRemoteNowPlayingInfoPlaybackRate` field):

- `playbackRate > 0` → **playing**
- `playbackRate == 0` with a known title → **paused**
- Missing `playbackRate` with a known title → assumed **playing** (back-compat for sources that omit the field)
- No title → **silent**

If `nowplaying-cli` is missing or returns no track, the loop silently falls back to AppleScript against the native `Music.app`. The fallback reads `player state` so it can distinguish `playing`, `paused`, and `stopped` the same way. If that also returns nothing, the status text falls back to `🔇 sound of silence`.

## Caveats

- `nowplaying-cli` relies on the private `MediaRemote` framework. On modern macOS (14.4+) Apple has tightened access to this API. The maintained `nowplaying-cli` build works as of writing, but if Apple ever closes it further the primary path will return empty and the AppleScript fallback (native `Music.app` only) is what you'll be left with.
- **Track detection runs on every invocation, not just `musical_myth`.** The internal mode map is built eagerly, so `nowplaying-cli` (and the AppleScript fallback if needed) is shelled out even for `myth`, `lunch`, `break`, and `clear`. macOS is effectively required for any mode; on non-macOS systems the call fails and the script keeps going.
- **Paused state depends on `playbackRate`.** A handful of media sources omit the field; for those, `musical_myth` will keep showing the playing line even while paused. Spot-check your main players (Spotify desktop, Music.app, browser tabs) the first time you run it.
- See [Troubleshooting](troubleshooting.md) for more gotchas.
