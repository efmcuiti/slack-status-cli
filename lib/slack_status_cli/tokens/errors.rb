module SlackStatusCli
  module Tokens
    # Token-resolution error hierarchy, extracted verbatim from the old
    # `TokenResolver::*Error` classes so the Tokens pod owns its own failure
    # vocabulary. The legacy classes survive in `lib/token_resolver.rb` until
    # the T4.5 cleanup.
    module Errors
      class Error < StandardError; end
      class NotFoundError < Error; end
      class ConfigError < Error; end
      class ManualWriteRequired < Error; end
      class WriteError < Error; end
    end
  end
end
