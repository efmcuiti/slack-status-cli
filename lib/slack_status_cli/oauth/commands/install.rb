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

        def initialize(client_id:, client_secret:, scopes:, port:, timeout:, logger: nil)
          @client_id = client_id
          @client_secret = client_secret
          @scopes = scopes
          @port = port
          @timeout = timeout
          @logger = logger
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

          yield(authorize_url: authorize_url, redirect_uri: redirect_uri) if block_given?

          callback = WaitForCallback.call(port: port, timeout: timeout, expected_state: state)
          result = ExchangeCode.call(
            code: callback[:code],
            client_id: client_id,
            client_secret: client_secret,
            redirect_uri: redirect_uri
          )

          result.merge(authorize_url: authorize_url, redirect_uri: redirect_uri)
        end

        private

        attr_reader :client_id, :client_secret, :scopes, :port, :timeout, :logger
      end
    end
  end
end
