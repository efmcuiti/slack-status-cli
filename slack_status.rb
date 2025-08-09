$LOAD_PATH.unshift(File.join(__dir__, "lib"))

require 'music'
require 'net/http'
require 'json'
require 'uri'

def trim_slack_status(str, max_len: 100, ellipsis: "…")
  return str if str.to_s.strip.empty? || str.grapheme_clusters.length <= max_len

  # leave room for ellipsis
  hard_limit = [max_len - ellipsis.grapheme_clusters.length, 0].max
  chunks = str.grapheme_clusters
  slice = chunks.first(hard_limit).join

  # try to trim at last whitespace within the slice
  soft = slice.rpartition(/\s/).first
  trimmed = soft.empty? ? slice : soft.rstrip

  "#{trimmed}#{ellipsis}"
end

def format_tune
  tune = Music.current_track
  return "🔇 sound of silence" if tune[:name].nil?
  trim_slack_status(
    "ヽ(o´∀`)ﾉ♪♬ :music: #{tune[:name]} - #{tune[:artist]} (#{tune[:album]})"
  )
end

# --- CONFIGURATION ---
SLACK_TOKEN = ENV['SLACK_SECRET_TOKEN']
MYTH_MOJIS = [":wolf:", ":lion_face:", ":phoenix_ash:", ":fox_face:", ":butterfly:"]
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
  },
  musical_myth: {
    text: format_tune,
    emoji: MYTH_MOJIS.sample
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

trap("INT") do
  puts "\nStopping Music tracker… sending goodbye to Music ❤️"
  # Your final command here, e.g.:
  `osascript -e 'tell application "Music" to pause'`
  send_status("", "")
  exit
end

trap("TERM") do
  puts "\nReceived TERM signal… cleaning up 🎩"
  # cleanup code here
  send_status("", "")
  exit
end

# --- ENTRY POINT ---
if __FILE__ == $0
  mode = ARGV.fetch(0, "myth").to_sym
  if mode == :clear
    send_status("", "")
    return
  end

  text = ARGV[1] || MODE_MAPS[mode][:text]
  emoji = ARGV[2] || MODE_MAPS[mode][:emoji]
  expiration = MODE_MAPS[mode][:expiration] || 0

  if mode == :musical_myth
    loop do
      text = format_tune
      puts "Updating status with: #{text}"
      send_status(text, emoji, expiration)
      puts "😴 for 120 seconds... (aka 2 minutes 😅)"
      sleep 120
    end
  else
    send_status(text, emoji, expiration)
  end
end
