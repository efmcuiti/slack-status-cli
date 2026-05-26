module SlackStatusCli
  # Defense-in-depth: replaces any Slack-shaped token (xoxp-, xoxb-, xoxa-,
  # xoxc-, xoxd-, xoxs-, xoxr-) inside an arbitrary string with
  # "xox?-…LAST4" so log lines, exception messages, and response snippets
  # can't accidentally leak a live secret. Idempotent and safe on nil.
  class SecretScrubber
    extend Callable

    SECRET_PATTERN = /\bxox[a-z]-[A-Za-z0-9-]+/

    def initialize(text:)
      @text = text
    end

    def call
      return nil if text.nil?
      text.to_s.gsub(SECRET_PATTERN) { |match| "xox?-…#{match[-4, 4]}" }
    end

    private

    attr_reader :text
  end
end
