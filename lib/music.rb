require 'open3'

class Music
  NULL_RESPONSE = "null|null|null"
  NULL_TRACK = { name: nil, artist: nil, album: nil }.freeze

  SAFE_MUSIC_SCRIPT = <<~APPLESCRIPT
    tell application "Music"
      if not running then return "#{NULL_RESPONSE}"
      if player state is stopped then return "#{NULL_RESPONSE}"
      try
        set t to current track
        return (name of t) & "|" & (artist of t) & "|" & (album of t)
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
    stdout, stderr, status = Open3.capture3("nowplaying-cli", "get", "title", "artist", "album")

    unless status.success?
      puts "⛔️ nowplaying-cli failed: #{stderr.strip}"
      return NULL_TRACK.dup
    end

    title, artist, album = stdout.split("\n").map(&:to_s).map(&:strip)

    {
      name: nullify(title),
      artist: nullify(artist),
      album: nullify(album)
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

    parts = stdout.strip.split("|")

    {
      name: nullify(parts[0]),
      artist: nullify(parts[1]),
      album: nullify(parts[2])
    }
  end
  private_class_method :fetch_apple_music_fallback

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
