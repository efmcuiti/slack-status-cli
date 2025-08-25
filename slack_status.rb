$LOAD_PATH.unshift(File.join(__dir__, "lib"))

require 'slack'
require 'net/http'
require 'json'
require 'uri'

slack = nil

%w[INT TERM].each do |sig|
  trap(sig) do
    puts "\nStopping Slack client… sending goodbye to Music ❤️"
    slack&.clear_status
    exit
  end
end

if __FILE__ == $0
  mode = ARGV[0]&.to_sym
  text = ARGV[1] # As optional String
  emoji = ARGV[2] # As optional String
  expiration = ARGV[3] # As optional Integer (in seconds)

  slack = Slack.new(mode: mode, text: text, emoji: emoji, expiration: expiration)
  
  slack.update_status
end
