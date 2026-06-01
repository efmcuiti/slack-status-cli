module SlackStatusCli
  module Slack
    module Queries
      # Calls auth.test to validate the token and resolve the workspace/user it
      # belongs to. Returns the parsed JSON response on success and lets
      # Http::GetRequest raise on any non-2xx response.
      class AuthTest
        extend Callable

        PATH = "auth.test".freeze

        def initialize(token:)
          @token = token
        end

        def call
          Http::GetRequest.call(token: token, path: PATH)
        end

        private

        attr_reader :token
      end
    end
  end
end
