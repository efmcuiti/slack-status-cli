require 'music'
require 'net/http'
require 'json'
require 'uri'

class Slack
  SLACK_TOKEN = ENV['SLACK_SECRET_TOKEN']
  MYTH_MOJIS = [":wolf:", ":lion_face:", ":phoenix_ash:", ":fox_face:", ":butterfly:"]

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
        music_status_update
        puts "😴 for 120 seconds... (aka 2 minutes 😅)"
        sleep 120
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
    self.text = format_tune
    puts "Updating status with: #{text}"
    send_status
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

  def format_tune
    tune = Music.current_track
    return "🔇 sound of silence" if tune[:name].nil?
    trim_slack_status(
      "ヽ(o´∀`)ﾉ♪♬  #{MYTH_MOJIS.sample} #{tune[:name]} - #{tune[:artist]} (#{tune[:album]})"
    )
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
    response = JSON.parse(res.body)
    if response["ok"]
      puts "✅ Slack status updated!"
    else
      puts "❌ Failed to update status: #{response["error"]}"
    end
  end
end
