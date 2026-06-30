module SlackStatusCli
  module Cli
    module Commands
      # Deep-merges a defaults hash into the config's `global` section and writes
      # the result back to disk. Loading + writing go through the Tokens config-IO
      # callables so the atomic-write and dir-creation guarantees are reused.
      class PersistGlobalDefaults
        extend Callable

        def initialize(defaults:, config_path: Tokens::Constants::DEFAULT_CONFIG_PATH)
          @defaults = defaults || {}
          @config_path = config_path
        end

        def call
          config = Tokens::Queries::LoadConfig.call(path: config_path)
          config["global"] = deep_merge(config["global"] || {}, defaults)
          Tokens::Commands::WriteConfig.call(config: config, path: config_path)
          nil
        end

        private

        attr_reader :defaults, :config_path

        def deep_merge(base, overlay)
          base.merge(overlay) do |_key, old_value, new_value|
            if old_value.is_a?(::Hash) && new_value.is_a?(::Hash)
              deep_merge(old_value, new_value)
            else
              new_value
            end
          end
        end
      end
    end
  end
end
