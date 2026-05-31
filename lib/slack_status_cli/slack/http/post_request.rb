require "net/http"
require "uri"

module SlackStatusCli
  module Slack
    module Http
      # Wraps a POST against the Slack Web API with the bearer auth header and a
      # JSON content type. Returns the raw Net::HTTPResponse rather than parsing
      # it: the caller (ResponseLogger) decides how to surface ok/non-ok and is
      # responsible for handling non-2xx, so this Callable never raises on them.
      class PostRequest
        extend Callable

        BASE_URL = "https://slack.com/api/".freeze
        CONTENT_TYPE = "application/json; charset=utf-8".freeze

        def initialize(token:, path:, body:)
          @token = token
          @path = path
          @body = body
        end

        def call
          Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |https|
            https.request(request)
          end
        end

        private

        attr_reader :token, :path, :body

        def uri
          URI.join(BASE_URL, path)
        end

        def request
          Net::HTTP::Post.new(uri).tap do |req|
            req["Authorization"] = "Bearer #{token}"
            req["Content-Type"] = CONTENT_TYPE
            req.body = body
          end
        end
      end
    end
  end
end
