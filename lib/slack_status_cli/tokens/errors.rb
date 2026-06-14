module SlackStatusCli
  module Tokens
    # Token-resolution error hierarchy. The Tokens pod owns its own failure
    # vocabulary.
    module Errors
      class Error < StandardError; end
      class NotFoundError < Error; end
      class ConfigError < Error; end
      class ManualWriteRequired < Error; end
      class WriteError < Error; end
    end
  end
end
