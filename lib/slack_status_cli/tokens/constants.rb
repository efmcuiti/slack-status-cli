module SlackStatusCli
  module Tokens
    # Shared filesystem locations for the Tokens pod, so the config-IO callables
    # don't each re-derive the same paths.
    module Constants
      DEFAULT_CONFIG_PATH = ::File.expand_path("~/.config/slack-status-cli/config.yml").freeze
    end
  end
end
