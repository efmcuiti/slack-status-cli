require "json"

module SlackStatusCli
  module Slack
    module Builders
      # Builds the JSON body for Slack's users.profile.set. Composes
      # ExpirationSeconds so callers can pass a raw expiration input ("30m",
      # an epoch string, or nil); a nil resolution becomes 0, which Slack
      # interprets as "no expiration".
      class StatusPayload
        extend Callable

        def initialize(text:, emoji:, expiration:, now: Time.now)
          @text = text
          @emoji = emoji
          @expiration = expiration
          @now = now
        end

        def call
          {
            profile: {
              status_text: text,
              status_emoji: emoji,
              status_expiration: resolved_expiration
            }
          }.to_json
        end

        private

        attr_reader :text, :emoji, :expiration, :now

        def resolved_expiration
          ExpirationSeconds.call(value: expiration, now: now) || 0
        end
      end
    end
  end
end
