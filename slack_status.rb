require 'net/http'
require 'json'
require 'uri'

# --- CONFIGURATION ---
SLACK_TOKEN = ENV['SLACK_SECRET_TOKEN']
MYTH_MOJIS = [":wolf:", ":lion_face:", ":fire:", ":fox_face:"]
MODE_MAPS = {
  myth: {
    text: "",
    emoji: MYTH_MOJIS.sample
  },
  lunch: {
    text: "#{MYTH_MOJIS.sample} - Lunch time!",
    emoji: ":meat_on_bone:",
    expiration: Time.now.to_i + 3600
  },
  break: {
    text: "#{MYTH_MOJIS.sample} Taking a break",
    emoji: ":coffee:",
    expiration: Time.now.to_i + 1800
  }
}

def build_payload(text:, emoji:, expiration: 0)
  {
    profile: {
      status_text: text,
      status_emoji: emoji,
      status_expiration: expiration
    }
  }.to_json
end

def send_status(text, emoji, expiration = 0)
  uri = URI("https://slack.com/api/users.profile.set")
  payload = build_payload(text: text, emoji: emoji, expiration: expiration)
  req = Net::HTTP::Post.new(uri)
  req["Content-Type"] = "application/json; charset=utf-8"
  req["Authorization"] = "Bearer #{SLACK_TOKEN}"
  req.body = payload

  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(req)
  end

  handle_response(res)
end

def handle_response(res)
  response = JSON.parse(res.body)
  if response["ok"]
    puts "✅ Slack status updated!"
  else
    puts "❌ Failed to update status: #{response["error"]}"
  end
end

# --- ENTRY POINT ---
if __FILE__ == $0
  mode = ARGV[0] || "myth"
  if mode == "clear"
    send_status("", "")
    return
  end

  text = ARGV[1] || MODE_MAPS[mode.to_sym][:text]
  emoji = ARGV[2] || MODE_MAPS[mode.to_sym][:emoji]
  expiration = MODE_MAPS[mode.to_sym][:expiration] || 0

  send_status(text, emoji, expiration)
end
