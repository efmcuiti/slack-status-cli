module SlackStatusCli
  module Oauth
    # OAuth install-flow error hierarchy. The Oauth pod owns its own failure
    # vocabulary, mirroring the Tokens pod.
    module Errors
      class Error < StandardError; end
      class StateMismatch < Error; end
      class Timeout < Error; end
      class ExchangeFailed < Error; end
      class PortBusy < Error; end
    end
  end
end
