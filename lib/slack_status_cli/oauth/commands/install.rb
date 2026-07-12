require "securerandom"

module SlackStatusCli
  module Oauth
    module Commands
      # Untested orchestrator glue: runs the whole user-token OAuth install flow
      # against a Slack App the user created once. Generates the CSRF state,
      # builds the authorize URL, waits for the loopback callback, and exchanges
      # the returned code for an xoxp- token.
      #
      # Yields { authorize_url:, redirect_uri: } before blocking on the callback
      # so the caller (the CLI) can print and open the browser; the flow itself
      # stays UI-agnostic. Returns the ExchangeCode result merged with the
      # authorize_url and redirect_uri that were used.
      class Install
        extend Callable

        def initialize(client_id:, client_secret:, scopes:, port:, timeout:, telemetry: Telemetry::NullLogger.new)
          @client_id = client_id
          @client_secret = client_secret
          @scopes = scopes
          @port = port
          @timeout = timeout
          @telemetry = telemetry
        end

        def call
          state = SecureRandom.hex(16)
          redirect_uri = "http://localhost:#{port}/callback"
          authorize_url = Queries::AuthorizeUrl.call(
            client_id: client_id,
            redirect_uri: redirect_uri,
            scopes: scopes,
            state: state
          )

          # Normalize scopes to a comma-joined string (callers pass an Array or a
          # String) so the tag schema stays stable, matching AuthorizeUrl's join.
          telemetry.rich_log(message: "oauth install started", tags: { port: port, scopes: Array(scopes).join(",") })

          yield(authorize_url: authorize_url, redirect_uri: redirect_uri) if block_given?

          callback = WaitForCallback.call(port: port, timeout: timeout, expected_state: state)
          result = exchange(callback[:code], redirect_uri)

          # Identity/scope only — never the token itself.
          telemetry.rich_log(
            message: "oauth token exchanged",
            tags: { user_id: result[:user_id], team_id: result[:team_id], team_name: result[:team_name] }
          )
          telemetry.rich_log(message: "oauth scope granted", tags: { scope: result[:scope] })

          result.merge(authorize_url: authorize_url, redirect_uri: redirect_uri)
        end

        private

        attr_reader :client_id, :client_secret, :scopes, :port, :timeout, :telemetry

        def exchange(code, redirect_uri)
          ExchangeCode.call(
            code: code,
            client_id: client_id,
            client_secret: client_secret,
            redirect_uri: redirect_uri
          )
        rescue StandardError => e
          # Rescue broadly so network/JSON failures (not just Errors::Error) stay
          # observable, and scrub the reason so a token can't leak even through a
          # scrub-bypassing telemetry fake.
          telemetry.rich_log(
            message: "oauth token exchange failed",
            level: :error,
            tags: { reason: SecretScrubber.call(text: e.message.to_s) }
          )
          raise
        end
      end
    end
  end
end
