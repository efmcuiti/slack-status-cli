require "json"

module SlackStatusCli
  module Cli
    module Commands
      # Orchestrates the `config` subcommand: `get`, `set`, and `path`. Reads and
      # writes go through the Tokens config-IO callables; the dotted-key plumbing
      # and scalar coercion are delegated to the injected Cli queries/commands so
      # this orchestrator only owns the subcommand dispatch + I/O. Failures raise
      # the Cli pod's errors (a missing key raises ConfigKeyUnset) rather than
      # calling exit — the dispatcher owns process control.
      class Config
        extend Callable

        HELP = <<~HELP.freeze
          config get <dotted.key>          # e.g. config get global.storage_backend
          config set <dotted.key> <value>  # e.g. config set global.storage_backend keychain
          config path                      # print the active config file path
        HELP

        def initialize(
          args:,
          options: {},
          output: $stdout,
          config_loader: Tokens::Queries::LoadConfig,
          config_writer: Tokens::Commands::WriteConfig,
          getter: Queries::DottedGet,
          setter: DottedSet,
          coercer: Queries::CoerceScalar
        )
          @args = args.dup
          @options = options || {}
          @output = output
          @config_loader = config_loader
          @config_writer = config_writer
          @getter = getter
          @setter = setter
          @coercer = coercer
        end

        def call
          case (sub = args.shift)
          when "get" then run_get
          when "set" then run_set
          when "path" then output.puts(config_path)
          when nil, "help", "-h", "--help" then output.puts(HELP)
          else
            raise Errors::Error, "Unknown config subcommand: #{sub}"
          end
          nil
        end

        private

        attr_reader :args, :options, :output, :config_loader, :config_writer, :getter, :setter, :coercer

        def run_get
          key = args.shift
          raise Errors::Error, "Usage: config get <dotted.key>" if blank?(key)

          config = config_loader.call(path: config_path)
          value = getter.call(hash: config, key: key)
          raise Errors::ConfigKeyUnset, "(unset) #{key}" if value.nil?

          output.puts(printable(value))
        end

        def run_set
          key = args.shift
          raise Errors::Error, "Usage: config set <dotted.key> <value>" if blank?(key)

          value = args.shift
          raise Errors::Error, "Usage: config set <dotted.key> <value>" if value.nil?

          config = config_loader.call(path: config_path)
          setter.call(hash: config, key: key, value: coercer.call(value: value))
          config_writer.call(config: config, path: config_path)
          output.puts("set #{key} = #{value}")
        end

        def config_path
          options[:config_path] || Tokens::Constants::DEFAULT_CONFIG_PATH
        end

        def printable(value)
          return ::JSON.pretty_generate(value) if value.is_a?(::Hash) || value.is_a?(::Array)

          value
        end

        def blank?(value)
          value.nil? || value.empty?
        end
      end
    end
  end
end
