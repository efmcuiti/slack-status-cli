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
          existing = config["global"] || {}
          unless existing.is_a?(::Hash)
            raise Tokens::Errors::ConfigError, "config 'global' is not a mapping (got #{existing.class})"
          end

          config["global"] = deep_merge(existing, stringify_keys(defaults))
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

        # The loaded config is string-keyed; normalize symbol-keyed defaults so a
        # Ruby caller's `{ oauth: {...} }` merges into the existing "oauth" subtree
        # instead of being collapsed (and clobbering it) on YAML stringify.
        def stringify_keys(obj)
          case obj
          when ::Hash then obj.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify_keys(v) }
          when ::Array then obj.map { |v| stringify_keys(v) }
          else obj
          end
        end
      end
    end
  end
end
