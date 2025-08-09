require 'open3'
require 'json'

class Music

  SAFE_MUSIC_SCRIPT = <<~APPLESCRIPT
    tell application "Music"
      if not running then return "{\\\"name\\\":null,\\\"artist\\\":null,\\\"album\\\":null}"
      if player state is stopped then return "{\\\"name\\\":null,\\\"artist\\\":null,\\\"album\\\":null}"
      try
        set t to current track
        set n to name of t
        set a to artist of t
        set al to album of t
        return "{\\\"name\\\":\\\"" & n & "\\\",\\\"artist\\\":\\\"" & a & "\\\",\\\"album\\\":\\\"" & al & "\\\"}"
      on error number -1728
        return "{\\\"name\\\":null,\\\"artist\\\":null,\\\"album\\\":null}"
      end try
    end tell
  APPLESCRIPT

  def self.current_track(lang: nil, script: SAFE_MUSIC_SCRIPT)
    cmd = ["osascript"]
    cmd += ["-l", lang] if lang
    cmd += ["-e", script]
    stdout, stderr, status = Open3.capture3(*cmd)
    [JSON.parse(stdout.strip), stderr.strip, status.success?]
    puts "⛔️ Could not get current track: #{stderr.strip}" unless status.success?
    JSON.parse(stdout.strip, symbolize_names: true)
  end

  def playpause
    `osascript -e 'tell application "Music" to playpause'`
  end
end

puts "Music: #{Music.current_track}" if __FILE__ == $0
