module SlackStatusCli
  module Slack
    module Commands
      # Clears the Slack user status by delegating to SetStatus with an empty
      # text/emoji and a zero expiration, which Slack interprets as "no status".
      class ClearStatus
        extend Callable

        def initialize(token:, output: $stdout)
          @token = token
          @output = output
        end

        def call
          SetStatus.call(token: token, text: "", emoji: "", expiration: 0, output: output)
        end

        private

        attr_reader :token, :output
      end
    end
  end
end
