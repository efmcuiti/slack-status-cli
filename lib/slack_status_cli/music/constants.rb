module SlackStatusCli
  module Music
    # Shared null sentinels and the AppleScript fallback used by the Music
    # queries. Extracted verbatim from the old `Music` class so the new
    # Callable queries share a single source of truth for the "nothing is
    # playing" shape and the osascript payload.
    module Constants
      NULL_RESPONSE = "null|null|null|null".freeze

      NULL_TRACK = { name: nil, artist: nil, album: nil, playing: false }.freeze

      SAFE_MUSIC_SCRIPT = <<~APPLESCRIPT.freeze
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
    end
  end
end
