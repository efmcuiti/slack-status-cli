require "cgi"

module SlackStatusCli
  module Oauth
    module Views
      # The HTML the one-shot WEBrick listener serves when the callback fails.
      # The reason is HTML-escaped so a Slack-supplied or attacker-influenced
      # value can never inject markup. Kept byte-identical to the error copy
      # HandleCallbackRequest inlines today (T5.3 will delegate here).
      class ErrorPage
        extend Callable

        def initialize(reason:)
          @reason = reason
        end

        def call
          <<~HTML
            <!doctype html>
            <html><head><meta charset="utf-8"><title>slack-status-cli</title></head>
            <body style="font-family: -apple-system, system-ui, sans-serif; padding: 2rem; max-width: 36rem; margin: 0 auto;">
              <h1>❌ OAuth failed</h1>
              <p>#{CGI.escapeHTML(reason.to_s)}</p>
              <p>Return to your terminal for next steps.</p>
            </body></html>
          HTML
        end

        private

        attr_reader :reason
      end
    end
  end
end
