module SlackStatusCli
  module EmojiMigration
    module Queries
      # Coerces an emoji name into a filesystem-safe basename. Slack already
      # restricts names to a-z/0-9/_/-/+, but we defend against future surprises
      # by replacing anything outside that set (including whitespace) with "_".
      class SanitizeFilename
        extend Callable

        UNSAFE = /[^a-zA-Z0-9_+\-]/.freeze

        def initialize(name:)
          @name = name
        end

        def call
          name.to_s.gsub(UNSAFE, "_")
        end

        private

        attr_reader :name
      end
    end
  end
end
