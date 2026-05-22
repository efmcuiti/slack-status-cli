# Root namespace and autoload entry point for the slack-status-cli refactor.
#
# Every new Callable lives at `lib/slack_status_cli/<pod>/<...>.rb` and gets wired
# in here as it ships, so `require "slack_status_cli"` is the single entry point
# used by both `slack_status.rb` (the CLI dispatcher) and the spec_helper.
module SlackStatusCli
  autoload :Callable, "slack_status_cli/callable"
end
