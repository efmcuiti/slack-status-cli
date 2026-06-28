module SlackStatusCli
  module EmojiMigration
    # EmojiMigration pod error hierarchy. The pod owns its own failure
    # vocabulary, mirroring the Tokens and Oauth pods.
    module Errors
      class Error < StandardError; end
      class MissingScope < Error; end
    end
  end
end
