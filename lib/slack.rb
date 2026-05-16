require 'music'
require 'net/http'
require 'json'
require 'uri'

class Slack
  SLACK_TOKEN = ENV['SLACK_SECRET_TOKEN']
  MYTH_MOJIS = [":wolf:", ":lion_face:", ":phoenix_ash:", ":fox_face:", ":butterfly:"]

  PAUSED_PHRASES = [
    "intermission — the muse catches their breath",
    "the oracle is thinking…",
    "holding the lyre still",
    "mid-myth pause (not the final chapter)",
    "feral focus: recharge mode",
    "silence before the chorus",
    "the siren is on break",
    "embers cooling — not extinct"
  ]

  PLAYING_SLEEP = 120
  PAUSED_SLEEP = 30
  SILENT_SLEEP = 120

  def initialize(mode: :myth, emoji: nil, text: nil, expiration: 0)
    @mode = mode || :myth
    @emoji = emoji || mode_map&.fetch(:emoji)
    @text = text || mode_map&.fetch(:text)
    @expiration = evaluate_expiration(expiration) || mode_map&.fetch(:expiration, evaluate_expiration(expiration)) || 0
  end

  def update_status
    case mode
    when :clear
      clear_status
    when :musical_myth
      loop do
        tune =
          begin
            music_status_update
          rescue StandardError => e
            puts "⚠️  Tick failed: #{e.class}: #{e.message} — will retry next cycle."
            nil
          end

        interval = next_interval(tune)
        puts "😴 for #{interval} seconds... (#{state_label(tune)})"
        sleep interval
      end
    else
      send_status
    end
  end

  def clear_status
    reset_status
    send_status
  end

  private
  attr_accessor :mode, :emoji, :text, :expiration

  def evaluate_expiration(value)
    return if value.nil? || value.to_s.strip.empty?
    return unless integer_string?(value)
    Time.now.to_i + value.to_i
  end

  def integer_string?(str)
    /\A[+-]?\d+\z/.match?(str)
  end

  def reset_status
    self.text = ""
    self.emoji = ""
    self.expiration = 0
  end

  def send_status
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

  def music_status_update
    tune = Music.current_track
    self.text = format_tune(tune)
    puts "Updating status with: #{text}"
    send_status
    tune
  end

  def next_interval(tune)
    case tune_state(tune)
    when :paused then PAUSED_SLEEP
    when :silent then SILENT_SLEEP
    else PLAYING_SLEEP
    end
  end

  def state_label(tune)
    case tune_state(tune)
    when :paused then "paused — quick check-in"
    when :silent then "silent — long nap"
    else "playing — full cycle"
    end
  end

  # Unknown tune (tick errored out) defaults to :playing so we keep the
  # conservative 120s cadence instead of hammering Slack during transient
  # failures.
  def tune_state(tune)
    return :playing if tune.nil?
    return :silent if tune[:name].nil?
    tune[:playing] ? :playing : :paused
  end

  def mode_map
    @mode_map ||= mode_maps[mode]
  end

  def mode_maps
    @node_maps ||= {
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
        emoji: ":music:"
      }
    }
  end

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

  def format_tune(tune = Music.current_track)
    return "🔇 sound of silence" if tune[:name].nil?
    return trim_slack_status(paused_status(tune)) unless tune[:playing]
    trim_slack_status(playing_status(tune))
  end

  def playing_status(tune)
    "♪♬  #{MYTH_MOJIS.sample} #{tune[:name]} - #{tune[:artist]} (#{tune[:album]})"
  end

  def paused_status(tune)
    "⏸️ #{MYTH_MOJIS.sample} #{PAUSED_PHRASES.sample} — #{tune[:name]} - #{tune[:artist]}"
  end

  def build_payload(text:, emoji:, expiration: 0)
  {
    profile: {
      status_text: text,
      status_emoji: emoji,
      status_expiration: expiration
    }
  }.to_json
  end

  def handle_response(res)
    body = res.body.to_s

    unless res.is_a?(Net::HTTPSuccess)
      puts "❌ Slack HTTP #{res.code} #{res.message}#{body.strip.empty? ? '' : " — #{body_excerpt(body)}"}"
      return
    end

    if body.strip.empty?
      puts "⚠️  Empty response from Slack (HTTP #{res.code}); skipping this tick."
      return
    end

    response =
      begin
        JSON.parse(body)
      rescue JSON::ParserError => e
        puts "⚠️  Non-JSON response from Slack: #{e.message} — #{body_excerpt(body)}"
        return
      end

    if response["ok"]
      puts "✅ Slack status updated!"
    else
      puts "❌ Failed to update status: #{response["error"]}"
    end
  end

  def body_excerpt(body, limit: 200)
    snippet = body.strip
    snippet.length > limit ? "#{snippet[0, limit]}…" : snippet
  end
end
