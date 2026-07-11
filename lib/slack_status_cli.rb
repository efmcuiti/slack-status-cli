# Root namespace and autoload entry point for the slack-status-cli refactor.
#
# Every new Callable lives at `lib/slack_status_cli/<pod>/<...>.rb` and gets wired
# in here as it ships, so `require "slack_status_cli"` is the single entry point
# used by both `slack_status.rb` (the CLI dispatcher) and the spec_helper.
module SlackStatusCli
  autoload :Callable, "slack_status_cli/callable"
  autoload :SecretScrubber, "slack_status_cli/secret_scrubber"

  module Telemetry
    autoload :StructuredLogger, "slack_status_cli/telemetry/structured_logger"
    autoload :NullLogger, "slack_status_cli/telemetry/null_logger"
  end

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
    autoload :Constants, "slack_status_cli/tokens/constants"

    module Queries
      autoload :LoadConfig, "slack_status_cli/tokens/queries/load_config"
      autoload :MergedSettings, "slack_status_cli/tokens/queries/merged_settings"
      autoload :EnvVarName, "slack_status_cli/tokens/queries/env_var_name"
      autoload :ProfileExplicitlyConfigured, "slack_status_cli/tokens/queries/profile_explicitly_configured"
      autoload :NotFoundMessage, "slack_status_cli/tokens/queries/not_found_message"
      autoload :ResolveToken, "slack_status_cli/tokens/queries/resolve_token"
    end

    module Commands
      autoload :WriteConfig, "slack_status_cli/tokens/commands/write_config"
      autoload :WriteToken, "slack_status_cli/tokens/commands/write_token"
    end

    module Backends
      autoload :Base, "slack_status_cli/tokens/backends/base"
      autoload :Dashlane, "slack_status_cli/tokens/backends/dashlane"
      autoload :Keychain, "slack_status_cli/tokens/backends/keychain"
      autoload :File, "slack_status_cli/tokens/backends/file"
      autoload :Env, "slack_status_cli/tokens/backends/env"
    end
  end

  module Oauth
    autoload :Errors, "slack_status_cli/oauth/errors"

    module Queries
      autoload :AuthorizeUrl, "slack_status_cli/oauth/queries/authorize_url"
      autoload :HandleCallbackRequest, "slack_status_cli/oauth/queries/handle_callback_request"
    end

    module Commands
      autoload :ExchangeCode, "slack_status_cli/oauth/commands/exchange_code"
      autoload :WaitForCallback, "slack_status_cli/oauth/commands/wait_for_callback"
      autoload :Install, "slack_status_cli/oauth/commands/install"
    end

    module Views
      autoload :SuccessPage, "slack_status_cli/oauth/views/success_page"
      autoload :ErrorPage, "slack_status_cli/oauth/views/error_page"
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

  module Cli
    autoload :Errors, "slack_status_cli/cli/errors"

    module Queries
      autoload :ParseGlobalFlags, "slack_status_cli/cli/queries/parse_global_flags"
      autoload :DottedGet, "slack_status_cli/cli/queries/dotted_get"
      autoload :CoerceScalar, "slack_status_cli/cli/queries/coerce_scalar"
      autoload :AdminUrl, "slack_status_cli/cli/queries/admin_url"
      autoload :DoctorHint, "slack_status_cli/cli/queries/doctor_hint"
      autoload :RedactedToken, "slack_status_cli/cli/queries/redacted_token"
      autoload :ReadSecretRef, "slack_status_cli/cli/queries/read_secret_ref"
      autoload :ResolveClientId, "slack_status_cli/cli/queries/resolve_client_id"
      autoload :ResolveClientSecret, "slack_status_cli/cli/queries/resolve_client_secret"
      autoload :ResolveBackend, "slack_status_cli/cli/queries/resolve_backend"
      autoload :ProfileHasToken, "slack_status_cli/cli/queries/profile_has_token"
    end

    module Commands
      autoload :OpenInBrowser, "slack_status_cli/cli/commands/open_in_browser"
      autoload :PersistGlobalDefaults, "slack_status_cli/cli/commands/persist_global_defaults"
      autoload :PersistProfileToken, "slack_status_cli/cli/commands/persist_profile_token"
      autoload :DottedSet, "slack_status_cli/cli/commands/dotted_set"
      autoload :InstallSignalHandlers, "slack_status_cli/cli/commands/install_signal_handlers"
      autoload :PrintAppCreationInstructions, "slack_status_cli/cli/commands/print_app_creation_instructions"
      autoload :Config, "slack_status_cli/cli/commands/config"
      autoload :Profiles, "slack_status_cli/cli/commands/profiles"
      autoload :Doctor, "slack_status_cli/cli/commands/doctor"
      autoload :MigrateEmojis, "slack_status_cli/cli/commands/migrate_emojis"
      autoload :RunStatusMode, "slack_status_cli/cli/commands/run_status_mode"
      autoload :Setup, "slack_status_cli/cli/commands/setup"
    end
  end

  module EmojiMigration
    autoload :Errors, "slack_status_cli/emoji_migration/errors"

    module Queries
      autoload :FilteredEntries, "slack_status_cli/emoji_migration/queries/filtered_entries"
      autoload :ExtensionFor, "slack_status_cli/emoji_migration/queries/extension_for"
      autoload :SanitizeFilename, "slack_status_cli/emoji_migration/queries/sanitize_filename"
      autoload :HumanBytes, "slack_status_cli/emoji_migration/queries/human_bytes"
    end

    module Commands
      autoload :DownloadImage, "slack_status_cli/emoji_migration/commands/download_image"
      autoload :WriteAliases, "slack_status_cli/emoji_migration/commands/write_aliases"
      autoload :WriteSkipped, "slack_status_cli/emoji_migration/commands/write_skipped"
      autoload :Run, "slack_status_cli/emoji_migration/commands/run"
    end
  end
end
