# Root namespace and autoload entry point for the slack-status-cli refactor.
#
# Every new Callable lives at `lib/slack_status_cli/<pod>/<...>.rb` and gets wired
# in here as it ships, so `require "slack_status_cli"` is the single entry point
# used by both `slack_status.rb` (the CLI dispatcher) and the spec_helper.
module SlackStatusCli
  autoload :Callable, "slack_status_cli/callable"
  autoload :SecretScrubber, "slack_status_cli/secret_scrubber"

  module Slack
    module Formatters
      autoload :StatusTextTrimmer, "slack_status_cli/slack/formatters/status_text_trimmer"
      autoload :TuneText, "slack_status_cli/slack/formatters/tune_text"
      autoload :NextInterval, "slack_status_cli/slack/formatters/next_interval"
      autoload :StateLabel, "slack_status_cli/slack/formatters/state_label"
      autoload :ResponseLogger, "slack_status_cli/slack/formatters/response_logger"
    end

    module Builders
      autoload :ExpirationSeconds, "slack_status_cli/slack/builders/expiration_seconds"
    end
  end
end
