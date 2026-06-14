require "cgi"

module SlackStatusCli
  module Oauth
    module Queries
      # Pure extract of the WEBrick mount_proc body: takes the redirect query
      # params and the expected CSRF state, then returns the payload + HTTP
      # status the one-shot listener should serve. Slack error wins first, then
      # the state guard, then the missing-code guard, else success.
      class HandleCallbackRequest
        extend Callable

        def initialize(params:, expected_state:)
          @params = params || {}
          @expected_state = expected_state
        end

        def call
          return error_result(slack_error) if slack_error
          return error_result("state_mismatch") unless state_matches?
          return error_result("missing_code") if blank?(code)

          {
            code: code,
            state: params["state"],
            error: nil,
            status: 200,
            body: success_body
          }
        end

        private

        attr_reader :params, :expected_state

        def slack_error
          value = params["error"]
          value unless blank?(value)
        end

        def state_matches?
          params["state"] == expected_state
        end

        def code
          params["code"]
        end

        def error_result(error)
          {
            code: nil,
            state: params["state"],
            error: error,
            status: 400,
            body: error_body(error)
          }
        end

        def blank?(value)
          value.nil? || value.to_s.empty?
        end

        def success_body
          <<~HTML
            <!doctype html>
            <html><head><meta charset="utf-8"><title>slack-status-cli</title></head>
            <body style="font-family: -apple-system, system-ui, sans-serif; padding: 2rem; max-width: 36rem; margin: 0 auto;">
              <h1>✅ Slack token received</h1>
              <p>You can close this tab. Return to your terminal to finish setup.</p>
            </body></html>
          HTML
        end

        def error_body(reason)
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
      end
    end
  end
end
