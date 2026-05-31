require "net/http"
require "json"
require "uri"

module SlackStatusCli
  module Slack
    module Http
      # Wraps a GET against the Slack Web API. Slack documents auth.test and
      # emoji.list as GET-friendly (no body required). Returns parsed JSON on a
      # 2xx response, raises on any non-2xx; transport-level errors propagate
      # unchanged so callers can distinguish "Slack said no" from "network down".
      class GetRequest
        extend Callable

        BASE_URL = "https://slack.com/api/".freeze
        ABSOLUTE_PATH = %r{\A(?:[a-z][a-z0-9+.-]*:)?//|\A/}i.freeze

        def initialize(token:, path:)
          @token = token
          @path = path
        end

        def call
          response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |https|
            https.request(request)
          end

          unless response.is_a?(Net::HTTPSuccess)
            raise "Slack HTTP #{response.code} #{response.message}"
          end

          JSON.parse(response.body)
        end

        private

        attr_reader :token, :path

        # Append the API method to the fixed base by string concatenation so a
        # caller-supplied `path` can never replace the host and leak the bearer
        # token elsewhere. Absolute or scheme-relative paths are a programming
        # error, so we raise loudly rather than silently rewriting intent.
        def uri
          if ABSOLUTE_PATH.match?(path.to_s)
            raise ArgumentError, "path must be a relative Slack API method, got: #{path.inspect}"
          end

          URI("#{BASE_URL}#{path}")
        end

        def request
          Net::HTTP::Get.new(uri).tap do |req|
            req["Authorization"] = "Bearer #{token}"
          end
        end
      end
    end
  end
end
