module SlackStatusCli
  module Cli
    module Commands
      # Orchestrates the `profiles` subcommand: `list` (the default) prints each
      # configured profile with its effective storage backend, and `add <name>`
      # creates an empty profile entry. Config I/O goes through the Tokens
      # callables; unknown subcommands raise the Cli pod's Error rather than
      # aborting, leaving process control to the dispatcher.
      class Profiles
        extend Callable

        NO_PROFILES = "(no profiles configured; run: ruby slack_status.rb setup --profile <name>)".freeze
        UNSET = "(unset)".freeze

        def initialize(
          args:,
          options: {},
          output: $stdout,
          config_loader: Tokens::Queries::LoadConfig,
          config_writer: Tokens::Commands::WriteConfig
        )
          @args = args.dup
          @options = options || {}
          @output = output
          @config_loader = config_loader
          @config_writer = config_writer
        end

        def call
          case (sub = args.shift || "list")
          when "list" then run_list
          when "add" then run_add
          else
            raise Errors::Error, "Unknown profiles subcommand: #{sub}"
          end
          nil
        end

        private

        attr_reader :args, :options, :output, :config_loader, :config_writer

        def run_list
          config = config_loader.call(path: config_path)
          profiles = (config["profiles"] || {}).keys
          return output.puts(NO_PROFILES) if profiles.empty?

          global_backend = config.dig("global", "storage_backend") || UNSET
          output.puts("Global default backend: #{global_backend}")
          profiles.each do |name|
            backend = config.dig("profiles", name, "storage_backend") || global_backend
            output.puts("  - #{name}  (backend=#{backend})")
          end
        end

        def run_add
          name = args.shift
          raise Errors::Error, "Usage: profiles add <name>" if name.nil? || name.empty?

          config = config_loader.call(path: config_path)
          config["profiles"] ||= {}
          config["profiles"][name] ||= {}
          config_writer.call(config: config, path: config_path)
          output.puts("added profile '#{name}'")
        end

        def config_path
          options[:config_path] || Tokens::Constants::DEFAULT_CONFIG_PATH
        end
      end
    end
  end
end
