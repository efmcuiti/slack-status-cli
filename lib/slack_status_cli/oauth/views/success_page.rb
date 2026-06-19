module SlackStatusCli
  module Oauth
    module Views
      # The HTML the one-shot WEBrick listener serves after a successful token
      # exchange. Kept byte-identical to the success copy HandleCallbackRequest
      # inlines today, so T5.3 can make the handler delegate here without the
      # page drifting.
      class SuccessPage
        extend Callable

        def call
          <<~HTML
            <!doctype html>
            <html><head><meta charset="utf-8"><title>slack-status-cli</title></head>
            <body style="font-family: -apple-system, system-ui, sans-serif; padding: 2rem; max-width: 36rem; margin: 0 auto;">
              <h1>✅ Slack token received</h1>
              <p>You can close this tab. Return to your terminal to finish setup.</p>
            </body></html>
          HTML
        end
      end
    end
  end
end
