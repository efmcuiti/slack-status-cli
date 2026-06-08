require "yaml"

module SlackStatusCli
  module Tokens
    module Queries
      # Loads the CLI's YAML config from disk and returns it as a deep-stringified
      # Hash. Missing or empty files yield `{}`; malformed YAML raises ConfigError.
      # Keys are stringified so downstream callables (MergedSettings, the
      # backends) never have to guard against symbol/integer keys.
      class LoadConfig
        extend Callable

        def initialize(path: Constants::DEFAULT_CONFIG_PATH)
          @path = path
        end

        attr_reader :path

        def call
          return {} unless ::File.exist?(path)

          parsed = YAML.safe_load(::File.read(path), permitted_classes: [], aliases: false)
          return {} if parsed.nil?

          unless parsed.is_a?(Hash)
            raise Errors::ConfigError, "#{path} is not a mapping (got #{parsed.class})"
          end

          deep_stringify(parsed)
        rescue Psych::Exception => e
          raise Errors::ConfigError, "Failed to parse #{path}: #{e.message}"
        end

        private

        def deep_stringify(obj)
          case obj
          when Hash then obj.each_with_object({}) { |(k, v), h| h[k.to_s] = deep_stringify(v) }
          when Array then obj.map { |v| deep_stringify(v) }
          else obj
          end
        end
      end
    end
  end
end
