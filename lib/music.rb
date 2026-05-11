require 'open3'
require 'json'

class Music
  NULL_RESPONSE = "null|null|null"
  NULL_TRACK = { name: nil, artist: nil, album: nil }.freeze
  VALID_SOURCES = %i[native web].freeze

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

  def self.current_track(source: :native, lang: nil, script: SAFE_MUSIC_SCRIPT)
    source = (source || :native).to_sym
    unless VALID_SOURCES.include?(source)
      raise ArgumentError, "unknown music source: #{source.inspect} (expected one of #{VALID_SOURCES.inspect})"
    end

    case source
    when :native then fetch_native(lang: lang, script: script)
    when :web    then fetch_web
    end
  end

  def self.fetch_native(lang: nil, script: SAFE_MUSIC_SCRIPT)
    cmd = ["osascript"]
    cmd += ["-l", lang] if lang
    cmd += ["-e", script]
    stdout, stderr, status = Open3.capture3(*cmd)

    unless status.success?
      puts "⛔️ Could not get current track: #{stderr.strip}"
      return NULL_TRACK.dup
    end

    parts = stdout.strip.split("|")

    {
      name: nullify(parts[0]),
      artist: nullify(parts[1]),
      album: nullify(parts[2])
    }
  end

  def self.fetch_web
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

  def self.nullify(value)
    return nil if value.nil?
    stripped = value.to_s.strip
    return nil if stripped.empty? || stripped == "null"
    stripped
  end

  def playpause
    `osascript -e 'tell application "Music" to playpause'`
  end
end

if __FILE__ == $0
  source = (ARGV[0] || "native").to_sym
  puts "Music (#{source}): #{Music.current_track(source: source)}"
end
