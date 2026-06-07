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
      autoload :ModeStatus, "slack_status_cli/slack/builders/mode_status"
      autoload :StatusPayload, "slack_status_cli/slack/builders/status_payload"
    end

    module Http
      autoload :GetRequest, "slack_status_cli/slack/http/get_request"
      autoload :PostRequest, "slack_status_cli/slack/http/post_request"
    end

    module Queries
      autoload :AuthTest, "slack_status_cli/slack/queries/auth_test"
      autoload :EmojiList, "slack_status_cli/slack/queries/emoji_list"
    end

    module Commands
      autoload :SetStatus, "slack_status_cli/slack/commands/set_status"
      autoload :ClearStatus, "slack_status_cli/slack/commands/clear_status"
      autoload :TickMusicalStatus, "slack_status_cli/slack/commands/tick_musical_status"
      autoload :RunMusicalLoop, "slack_status_cli/slack/commands/run_musical_loop"
      autoload :UpdateStatus, "slack_status_cli/slack/commands/update_status"
    end
  end

  module Tokens
    autoload :Errors, "slack_status_cli/tokens/errors"

    module Backends
      autoload :Base, "slack_status_cli/tokens/backends/base"
      autoload :Dashlane, "slack_status_cli/tokens/backends/dashlane"
      autoload :Keychain, "slack_status_cli/tokens/backends/keychain"
      autoload :File, "slack_status_cli/tokens/backends/file"
      autoload :Env, "slack_status_cli/tokens/backends/env"
    end
  end

  module Music
    autoload :Constants, "slack_status_cli/music/constants"

    module Queries
      autoload :NowPlaying, "slack_status_cli/music/queries/now_playing"
      autoload :AppleMusicFallback, "slack_status_cli/music/queries/apple_music_fallback"
      autoload :TuneState, "slack_status_cli/music/queries/tune_state"
      autoload :CurrentTrack, "slack_status_cli/music/queries/current_track"
    end
  end
end
