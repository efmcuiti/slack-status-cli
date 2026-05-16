require 'open3'
require 'json'

class Music
  NULL_RESPONSE = "null|null|null|null"
  NULL_TRACK = { name: nil, artist: nil, album: nil, playing: false }.freeze

  SAFE_MUSIC_SCRIPT = <<~APPLESCRIPT
    tell application "Music"
      if not running then return "#{NULL_RESPONSE}"
      if player state is stopped then return "#{NULL_RESPONSE}"
      try
        set t to current track
        set s to (player state as text)
        return s & "|" & (name of t) & "|" & (artist of t) & "|" & (album of t)
      on error number -1728
        return "#{NULL_RESPONSE}"
      end try
    end tell
  APPLESCRIPT

  def self.current_track
    track = fetch_now_playing
    return track unless track[:name].nil?

    fetch_apple_music_fallback
  end

  def self.fetch_now_playing
    stdout, stderr, status = Open3.capture3(
      "nowplaying-cli", "get", "--json", "title", "artist", "album", "playbackRate"
    )

    unless status.success?
      puts "⛔️ nowplaying-cli failed: #{stderr.strip}"
      return NULL_TRACK.dup
    end

    payload = parse_json(stdout)
    return NULL_TRACK.dup if payload.nil?

    title = nullify(payload["title"])
    return NULL_TRACK.dup if title.nil?

    {
      name: title,
      artist: nullify(payload["artist"]),
      album: nullify(payload["album"]),
      playing: playback_rate_to_playing(payload["playbackRate"])
    }
  rescue Errno::ENOENT
    puts "⛔️ `nowplaying-cli` not found. Install with: brew install nowplaying-cli"
    NULL_TRACK.dup
  end
  private_class_method :fetch_now_playing

  def self.fetch_apple_music_fallback
    stdout, stderr, status = Open3.capture3("osascript", "-e", SAFE_MUSIC_SCRIPT)

    unless status.success?
      puts "⛔️ AppleScript fallback failed: #{stderr.strip}"
      return NULL_TRACK.dup
    end

    state, name, artist, album = stdout.strip.split("|").map { |part| nullify(part) }
    return NULL_TRACK.dup if name.nil?

    {
      name: name,
      artist: artist,
      album: album,
      playing: state == "playing"
    }
  end
  private_class_method :fetch_apple_music_fallback

  def self.parse_json(raw)
    JSON.parse(raw.to_s.strip)
  rescue JSON::ParserError => e
    puts "⛔️ Could not parse nowplaying-cli JSON: #{e.message}"
    nil
  end
  private_class_method :parse_json

  # Treat an explicit playbackRate of 0 as paused. Missing/nil rate falls
  # back to "playing" to preserve prior behavior when MediaRemote omits the
  # field.
  def self.playback_rate_to_playing(rate)
    return false if rate.is_a?(Numeric) && rate <= 0
    return false if rate.is_a?(String) && rate.strip == "0"
    true
  end
  private_class_method :playback_rate_to_playing

  def self.nullify(value)
    return nil if value.nil?

    stripped = value.to_s.strip
    return nil if stripped.empty? || stripped == "null"

    stripped
  end
  private_class_method :nullify
end

if __FILE__ == $0
  puts "Music: #{Music.current_track}"
end
