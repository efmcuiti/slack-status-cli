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

        def initialize(token:, path:)
          @token = token
          @path = path
        end

        def call
          response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
            http.request(request)
          end

          unless response.is_a?(Net::HTTPSuccess)
            raise "Slack HTTP #{response.code} #{response.message}"
          end

          JSON.parse(response.body)
        end

        private

        attr_reader :token, :path

        def uri
          URI.join(BASE_URL, path)
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
