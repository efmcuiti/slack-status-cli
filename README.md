# slack-status-cli

A terminal-based Ruby script to update (and clear) your Slack status like a true code sorcerer ✨🔥

## 🛠️ Setup

1. **Get your Slack user token (`xoxp-...`)**
   - Create a Slack app at https://api.slack.com/apps
   - Add the scope `users.profile:write`
   - Install the app to your workspace and grab the token

2. **Set it as an environment variable**:

   ```bash
   export SLACK_USER_TOKEN=xoxp-...

---

## 🔥 Usage

```bash
ruby slack_status.rb                        # Sets a random mythological beast with no expiration
ruby slack_status.rb myth                   # Sets a random mythological beast with no expiration
ruby slack_status.rb lunch                  # Sets a lunch emoji and message for 1 hour
ruby slack_status.rb break                  # Sets a break emoji and message for 30 minutes
ruby slack_status.rb "" "In the zone" ":fire:" # Sets a custom message and emoji with no expiration
ruby slack_status.rb clear                  # Clears the status
ruby slack_status.rb musical_myth          # Sets a random musical mythological beast with no expiration and the current Music song!!
```
---

## 💡 Example

```bash
ruby slack_status.rb "" "Pair programming" ":busts_in_silhouette:"
```

---

## 📁 File Structure

```bash
.
├── slack_status.rb
└── README.md
```

---

## 📜 License

MIT — your code, your fire. Burn responsibly 🔥
