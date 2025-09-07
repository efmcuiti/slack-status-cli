require 'open3'
require 'json'

class Music
  NULL_RESPONSE = "null|null|null"

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

  def self.current_track(lang: nil, script: SAFE_MUSIC_SCRIPT)
    cmd = ["osascript"]
    cmd += ["-l", lang] if lang
    cmd += ["-e", script]
    stdout, stderr, status = Open3.capture3(*cmd)
    
    unless status.success?
      puts "⛔️ Could not get current track: #{stderr.strip}"
      return { name: nil, artist: nil, album: nil }
    end
    
    result = stdout.strip
    parts = result.split("|")
    
    {
      name: parts[0] == "null" ? nil : parts[0],
      artist: parts[1] == "null" ? nil : parts[1], 
      album: parts[2] == "null" ? nil : parts[2]
    }
  end

  def playpause
    `osascript -e 'tell application "Music" to playpause'`
  end
end

puts "Music: #{Music.current_track}" if __FILE__ == $0
