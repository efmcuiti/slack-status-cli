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

---

## 🔥 Usage

```bash
ruby slack_status.rb                        # Sets a random mythological beast emoji
ruby slack_status.rb myth                   # Sets a random mythological beast emoji
ruby slack_status.rb lunch                  # Sets lunch status (expires in 1 hour)
ruby slack_status.rb break                  # Sets break status (expires in 30 minutes)
ruby slack_status.rb clear                  # Clears the status
ruby slack_status.rb musical_myth           # Continuously updates with current Apple Music track
ruby slack_status.rb "" "Custom message" ":fire:" [expiration_seconds]  # Custom status
```

### Musical Myth Mode

The `musical_myth` mode runs continuously, updating your Slack status every 2 minutes with:
- A random mythological creature emoji
- Currently playing Apple Music track (song, artist, album)
- Graceful handling when no music is playing

Press `Ctrl+C` to stop and automatically clear your status.

---

## 💡 Examples

```bash
# Custom status with fire emoji
ruby slack_status.rb "" "Deep in the code" ":fire:"

# Custom status that expires in 1 hour (3600 seconds)
ruby slack_status.rb "" "In a meeting" ":speech_balloon:" 3600

# Start music tracking (runs until stopped)
ruby slack_status.rb musical_myth
```

---

## 📁 Project Structure

```
.
├── slack_status.rb        # Main CLI script
├── lib/
│   ├── slack.rb          # Slack API integration
│   └── music.rb          # Apple Music integration via AppleScript
└── README.md
```

---

## Requirements

- Ruby
- macOS (for Apple Music integration)
- Slack workspace with appropriate permissions

---

## 📜 License

MIT — your code, your fire. Burn responsibly 🔥
