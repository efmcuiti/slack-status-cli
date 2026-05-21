require 'json'
require 'net/http'
require 'securerandom'
require 'uri'
require 'webrick'

# Runs the Slack user-token OAuth install flow against a Slack App the user
# created once. Boots a one-shot WEBrick listener on 127.0.0.1, opens the
# browser at slack.com/oauth/v2/authorize, validates `state`, exchanges the
# returned code for an `xoxp-` token via oauth.v2.access, and returns it.
#
# Only depends on stdlib + the webrick gem.
class OAuthHelper
  class Error < StandardError; end
  class StateMismatch < Error; end
  class Timeout < Error; end
  class ExchangeFailed < Error; end
  class PortBusy < Error; end

  AUTHORIZE_URL = "https://slack.com/oauth/v2/authorize".freeze
  ACCESS_URL    = "https://slack.com/api/oauth.v2.access".freeze
  DEFAULT_PORT  = 53682
  DEFAULT_TIMEOUT_SECONDS = 120

  attr_reader :authorize_url, :redirect_uri

  def initialize(client_id:, client_secret:, scopes: %w[users.profile:write emoji:read], port: DEFAULT_PORT, timeout: DEFAULT_TIMEOUT_SECONDS, logger: nil)
    @client_id = client_id
    @client_secret = client_secret
    @scopes = scopes
    @port = port
    @timeout = timeout
    @logger = logger
    @state = SecureRandom.hex(16)
    @redirect_uri = "http://localhost:#{@port}/callback"
    @authorize_url = build_authorize_url
  end

  # Runs the flow. Yields the authorize URL to the caller (so it can print
  # before opening the browser); returns a hash with the resolved user token.
  def run
    yield @authorize_url if block_given?
    code = wait_for_callback
    exchange_code(code)
  end

  private

  def build_authorize_url
    params = {
      client_id: @client_id,
      user_scope: @scopes.join(","),
      redirect_uri: @redirect_uri,
      state: @state,
    }
    "#{AUTHORIZE_URL}?#{URI.encode_www_form(params)}"
  end

  # Boots a one-shot WEBrick listener bound to loopback only, waits for the
  # `/callback`, validates `state`, and returns the authorization `code`.
  # `ReuseAddr: true` so a killed-then-restarted setup doesn't have to wait
  # out the kernel's TIME_WAIT window on the socket.
  def wait_for_callback
    server =
      begin
        WEBrick::HTTPServer.new(
          Port: @port,
          BindAddress: "127.0.0.1",
          ReuseAddr: true,
          Logger: WEBrick::Log.new(File::NULL),
          AccessLog: [],
        )
      rescue Errno::EADDRINUSE
        raise PortBusy, <<~MSG.strip
          Port #{@port} is already in use on 127.0.0.1.
          Most likely a previous `setup` run is still alive. Find it and kill it:
            lsof -nP -iTCP:#{@port} -sTCP:LISTEN -t | xargs -r kill
          Then re-run: ruby slack_status.rb setup --profile <name> --rotate
        MSG
      end

    received_code = nil
    received_error = nil

    server.mount_proc("/callback") do |req, res|
      params = req.query
      if params["error"] && !params["error"].empty?
        received_error = "Slack returned error=#{params['error']}"
        res.status = 400
        res.body = error_page(received_error)
      elsif params["state"] != @state
        received_error = "OAuth state mismatch (CSRF guard)"
        res.status = 400
        res.body = error_page(received_error)
      elsif params["code"].nil? || params["code"].empty?
        received_error = "OAuth callback missing `code`"
        res.status = 400
        res.body = error_page(received_error)
      else
        received_code = params["code"]
        res.status = 200
        res.body = success_page
      end
      Thread.new { sleep 0.2; server.shutdown }
    end

    timer = Thread.new do
      sleep @timeout
      received_error ||= "OAuth callback timed out after #{@timeout}s"
      server.shutdown
    end

    trap("INT") { server.shutdown }
    server.start
    timer.kill if timer.alive?

    raise Timeout, received_error if received_error && received_error.include?("timed out")
    raise StateMismatch, received_error if received_error && received_error.include?("state mismatch")
    raise Error, received_error if received_error
    received_code
  end

  def exchange_code(code)
    uri = URI(ACCESS_URL)
    req = Net::HTTP::Post.new(uri)
    req.basic_auth(@client_id, @client_secret)
    req.set_form_data(
      "code" => code,
      "redirect_uri" => @redirect_uri,
    )

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end

    unless res.is_a?(Net::HTTPSuccess)
      raise ExchangeFailed, "Slack HTTP #{res.code}: #{res.body.to_s.strip[0, 200]}"
    end

    payload = JSON.parse(res.body)
    unless payload["ok"]
      raise ExchangeFailed, "oauth.v2.access error=#{payload['error']}"
    end

    user = payload["authed_user"] || {}
    token = user["access_token"]
    raise ExchangeFailed, "oauth.v2.access returned no authed_user.access_token" if token.nil? || token.empty?

    {
      token: token,
      scope: user["scope"],
      user_id: user["id"],
      team_id: payload.dig("team", "id"),
      team_name: payload.dig("team", "name"),
    }
  end

  def success_page
    <<~HTML
      <!doctype html>
      <html><head><meta charset="utf-8"><title>slack-status-cli</title></head>
      <body style="font-family: -apple-system, system-ui, sans-serif; padding: 2rem; max-width: 36rem; margin: 0 auto;">
        <h1>✅ Slack token received</h1>
        <p>You can close this tab. Return to your terminal to finish setup.</p>
      </body></html>
    HTML
  end

  def error_page(reason)
    <<~HTML
      <!doctype html>
      <html><head><meta charset="utf-8"><title>slack-status-cli</title></head>
      <body style="font-family: -apple-system, system-ui, sans-serif; padding: 2rem; max-width: 36rem; margin: 0 auto;">
        <h1>❌ OAuth failed</h1>
        <p>#{WEBrick::HTMLUtils.escape(reason)}</p>
        <p>Return to your terminal for next steps.</p>
      </body></html>
    HTML
  end
end
