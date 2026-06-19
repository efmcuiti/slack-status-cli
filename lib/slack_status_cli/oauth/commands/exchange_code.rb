require "json"
require "net/http"
require "uri"

module SlackStatusCli
  module Oauth
    module Commands
      # Exchanges the authorization code for an xoxp- user token via Slack's
      # oauth.v2.access endpoint, authenticating with HTTP Basic
      # (client_id:client_secret). Raises ExchangeFailed on any non-200, an
      # ok:false payload, or a response that carries no access_token.
      class ExchangeCode
        extend Callable

        ACCESS_URL = "https://slack.com/api/oauth.v2.access".freeze

        def initialize(code:, client_id:, client_secret:, redirect_uri:)
          @code = code
          @client_id = client_id
          @client_secret = client_secret
          @redirect_uri = redirect_uri
        end

        def call
          response = post
          unless response.is_a?(Net::HTTPSuccess)
            raise Errors::ExchangeFailed, "Slack HTTP #{response.code}: #{response.body.to_s.strip[0, 200]}"
          end

          payload = JSON.parse(response.body)
          raise Errors::ExchangeFailed, "oauth.v2.access error=#{payload['error']}" unless payload["ok"]

          user = payload["authed_user"] || {}
          token = user["access_token"]
          if token.nil? || token.empty?
            raise Errors::ExchangeFailed, "oauth.v2.access returned no authed_user.access_token"
          end

          {
            token: token,
            scope: user["scope"],
            user_id: user["id"],
            team_id: payload.dig("team", "id"),
            team_name: payload.dig("team", "name")
          }
        end

        private

        attr_reader :code, :client_id, :client_secret, :redirect_uri

        def post
          uri = URI(ACCESS_URL)
          request = Net::HTTP::Post.new(uri)
          request.basic_auth(client_id, client_secret)
          request.set_form_data("code" => code, "redirect_uri" => redirect_uri)

          Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
            http.request(request)
          end
        end
      end
    end
  end
end
