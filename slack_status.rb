$LOAD_PATH.unshift(File.join(__dir__, "lib"))

require 'slack'
require 'net/http'
require 'json'
require 'uri'

slack = nil
shutdown_requested = false

%w[INT TERM].each do |sig|
  trap(sig) do
    shutdown_requested = true
    exit
  end
end

at_exit do
  next unless shutdown_requested && slack
  puts "\nStopping Slack client… sending goodbye to Music ❤️"
  slack.clear_status
end

if __FILE__ == $0
  mode = ARGV[0]&.to_sym
  music_source = :native

  if mode == :musical_myth
    raw_source = ARGV[1]&.downcase
    music_source = (raw_source || "native").to_sym
    unless %i[native web].include?(music_source)
      abort "musical_myth source must be 'native' or 'web' (got: #{ARGV[1].inspect})"
    end
    text = nil
    emoji = nil
    expiration = nil
  else
    text = ARGV[1] # As optional String
    emoji = ARGV[2] # As optional String
    expiration = ARGV[3] # As optional Integer (in seconds)
  end

  slack = Slack.new(
    mode: mode,
    text: text,
    emoji: emoji,
    expiration: expiration,
    music_source: music_source
  )

  slack.update_status
end
