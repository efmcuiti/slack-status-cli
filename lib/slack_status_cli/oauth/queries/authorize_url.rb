require "uri"

module SlackStatusCli
  module Oauth
    module Queries
      # Pure builder for Slack's OAuth authorize URL. Joins the requested user
      # scopes with commas and form-encodes every param, so the redirect_uri is
      # percent-encoded and the caller never has to assemble the query by hand.
      class AuthorizeUrl
        extend Callable

        ENDPOINT = "https://slack.com/oauth/v2/authorize".freeze

        def initialize(client_id:, redirect_uri:, scopes:, state:)
          @client_id = client_id
          @redirect_uri = redirect_uri
          @scopes = scopes
          @state = state
        end

        def call
          params = {
            client_id: client_id,
            user_scope: Array(scopes).join(","),
            redirect_uri: redirect_uri,
            state: state
          }
          "#{ENDPOINT}?#{URI.encode_www_form(params)}"
        end

        private

        attr_reader :client_id, :redirect_uri, :scopes, :state
      end
    end
  end
end
