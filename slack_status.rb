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

  if mode == :musical_myth
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
    expiration: expiration
  )

  slack.update_status
end
