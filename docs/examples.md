# Examples

Copy-pasteable invocations. See [Usage](usage.md) for the full flag reference.

```bash
# Default — random mythological beast emoji on the active profile
ruby slack_status.rb

# Pick a profile explicitly (or set $SLACK_STATUS_PROFILE)
ruby slack_status.rb --profile work myth

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

# Use a one-off token without touching the resolver / config
ruby slack_status.rb --token xoxp-... clear

# Pull the token from Dashlane and pass it via env (one-shot)
dcli exec -- ruby slack_status.rb --token "$DASHLANE_SLACK_TOKEN" myth

# Validate the active profile's token
ruby slack_status.rb doctor --profile personal

# Configure global defaults once, then add multiple profiles
ruby slack_status.rb setup --global --client-id 1234.5678 --backend dashlane
ruby slack_status.rb setup --profile personal
ruby slack_status.rb setup --profile work

# Inspect / edit the config
ruby slack_status.rb config get global.storage_backend
ruby slack_status.rb config set profiles.work.storage_backend keychain
ruby slack_status.rb profiles list

# Debug music detection without touching Slack
ruby lib/music.rb
```
