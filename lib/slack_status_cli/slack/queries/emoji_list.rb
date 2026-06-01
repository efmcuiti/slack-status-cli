module SlackStatusCli
  module Slack
    module Queries
      # Calls emoji.list and returns the parsed JSON. Requires the emoji:read
      # scope on the user token. Each value in the returned "emoji" map is either
      # an HTTPS URL (real custom emoji) or "alias:<other_name>".
      class EmojiList
        extend Callable

        PATH = "emoji.list".freeze

        def initialize(token:)
          @token = token
        end

        def call
          Http::GetRequest.call(token: token, path: PATH)
        end

        private

        attr_reader :token
      end
    end
  end
end
