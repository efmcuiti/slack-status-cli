require "fileutils"
require "yaml"

module SlackStatusCli
  module Tokens
    module Commands
      # Persists the CLI config to disk as YAML, atomically: the payload is
      # written to a sibling temp file (0600), then renamed over the target so a
      # crash mid-write can never leave a half-written config. The parent
      # directory is created if missing. Returns nil.
      class WriteConfig
        extend Callable

        def initialize(config:, path: Constants::DEFAULT_CONFIG_PATH)
          @config = config
          @path = path
        end

        def call
          dir = ::File.dirname(path)
          ::FileUtils.mkdir_p(dir)

          tmp = ::File.join(dir, ".#{::File.basename(path)}.#{Process.pid}.#{rand(1_000_000)}.tmp")
          ::File.write(tmp, YAML.dump(deep_stringify(config)))
          ::File.chmod(0o600, tmp)
          ::File.rename(tmp, path)
          nil
        rescue StandardError
          ::File.delete(tmp) if tmp && ::File.exist?(tmp)
          raise
        end

        private

        attr_reader :config, :path

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
