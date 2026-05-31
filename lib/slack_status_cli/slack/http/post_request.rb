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
        ABSOLUTE_PATH = %r{\A(?:[a-z][a-z0-9+.-]*:)?//|\A/}i.freeze

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

        # Append the API method to the fixed base by string concatenation so a
        # caller-supplied `path` can never replace the host and leak the bearer
        # token and request body elsewhere. Absolute or scheme-relative paths
        # are a programming error, so we raise loudly rather than rewrite intent.
        def uri
          if ABSOLUTE_PATH.match?(path.to_s)
            raise ArgumentError, "path must be a relative Slack API method, got: #{path.inspect}"
          end

          URI("#{BASE_URL}#{path}")
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
