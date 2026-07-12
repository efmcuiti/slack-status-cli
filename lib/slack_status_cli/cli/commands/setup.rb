require "cli_prompt"

module SlackStatusCli
  module Cli
    module Commands
      # Orchestrates the `setup` subcommand — the user-token OAuth install flow.
      # Resolves the Slack App client_id / client_secret (prompting only when the
      # pure resolvers come up empty), then either persists global defaults
      # (--global) or runs the OAuth install and stores the resulting token under
      # the active profile. Interactive input goes through the injected `prompt`;
      # progress is written to `output`. Missing-but-required input raises a Cli
      # pod Error instead of calling exit, leaving process control to the
      # dispatcher.
      class Setup
        extend Callable

        SCOPES = %w[users.profile:write emoji:read].freeze
        PORT = 53_682
        TIMEOUT = 120
        DEFAULT_PROFILE = "default".freeze

        def initialize(
          options: {},
          output: $stdout,
          input: $stdin,
          env: ENV,
          prompt: ::CliPrompt,
          config_loader: Tokens::Queries::LoadConfig,
          config_writer: Tokens::Commands::WriteConfig,
          merged_settings: Tokens::Queries::MergedSettings,
          client_id_resolver: Queries::ResolveClientId,
          client_secret_resolver: Queries::ResolveClientSecret,
          backend_resolver: Queries::ResolveBackend,
          token_checker: Queries::ProfileHasToken,
          instructions: PrintAppCreationInstructions,
          oauth_installer: Oauth::Commands::Install,
          browser: OpenInBrowser,
          token_persister: PersistProfileToken,
          global_persister: PersistGlobalDefaults,
          redactor: Queries::RedactedToken,
          telemetry: Queries::ResolveTelemetry.call(env: env)
        )
          @options = options || {}
          @output = output
          @input = input
          @env = env
          @prompt = prompt
          @config_loader = config_loader
          @config_writer = config_writer
          @merged_settings = merged_settings
          @client_id_resolver = client_id_resolver
          @client_secret_resolver = client_secret_resolver
          @backend_resolver = backend_resolver
          @token_checker = token_checker
          @instructions = instructions
          @oauth_installer = oauth_installer
          @browser = browser
          @token_persister = token_persister
          @global_persister = global_persister
          @redactor = redactor
          @telemetry = telemetry
        end

        def call
          config = config_loader.call(path: config_path)
          client_id = resolve_client_id(config)

          return persist_global(config, client_id) if options[:global]

          client_secret = resolve_client_secret(config)
          backend = backend_resolver.call(config: config, profile: profile, env: env)

          return if existing_token_kept?

          result = install(client_id, client_secret)
          manual_pending = persist_token(config, backend, client_id, result[:token])
          output.puts(
            "Got #{redactor.call(token: result[:token])} " \
            "(scope=#{result[:scope]}, team=#{result[:team_name]})",
          )
          output.puts(completion_message(manual_pending))
          nil
        end

        private

        attr_reader :options, :output, :input, :env, :prompt, :config_loader, :config_writer,
                    :merged_settings, :client_id_resolver, :client_secret_resolver, :backend_resolver,
                    :token_checker, :instructions, :oauth_installer, :browser, :token_persister,
                    :global_persister, :redactor, :telemetry

        def resolve_client_id(config)
          resolved = presence(client_id_resolver.call(config: config, profile: profile, env: env))
          return resolved if resolved

          # Guard non-interactive BEFORE prompting: the real CliPrompt.ask raises
          # ArgumentError in that mode, which would escape as the wrong error type.
          raise Errors::Error, "Client ID is required (run without --non-interactive to enter it)" if non_interactive?

          instructions.call(output: output)
          value = presence(prompt.ask("Enter Client ID (from Basic Information):", input: input, output: output))
          value || raise(Errors::Error, "Client ID is required")
        end

        def resolve_client_secret(config)
          resolved = presence(client_secret_resolver.call(config: config, profile: profile, env: env))
          return resolved if resolved

          raise Errors::Error, "Client Secret is required (run without --non-interactive to enter it)" if non_interactive?

          value = presence(prompt.ask("Enter Client Secret (input hidden):", secret: true, input: input, output: output))
          value || raise(Errors::Error, "Client Secret is required")
        end

        def non_interactive?
          options[:non_interactive]
        end

        def persist_global(config, client_id)
          backend = backend_resolver.call(config: config, profile: profile, env: env)
          global_persister.call(
            defaults: { "oauth" => { "client_id" => client_id }, "storage_backend" => backend.to_s },
            config_path: config_path,
          )
          output.puts("Global defaults saved to #{config_path}.")
          output.puts("Setup complete!")
          nil
        end

        def existing_token_kept?
          return false if options[:rotate]
          return false unless token_checker.call(profile: profile, config_path: config_path)

          overwrite = prompt.ask_yes_no(
            "Profile '#{profile}' already has a token. Overwrite?",
            default: :no, input: input, output: output, non_interactive: options[:non_interactive],
          )
          return false if overwrite

          output.puts("Keeping existing token. Use --rotate to force.")
          true
        end

        def install(client_id, client_secret)
          oauth_installer.call(
            client_id: client_id, client_secret: client_secret,
            scopes: SCOPES, port: PORT, timeout: TIMEOUT, telemetry: telemetry
          ) do |authorize_url:, redirect_uri:|
            output.puts("Opening #{authorize_url[0, 80]}… in your browser.")
            output.puts("Listening on #{redirect_uri} (#{TIMEOUT}s timeout)…")
            browser.call(url: authorize_url)
          end
        rescue Oauth::Errors::Error => e
          raise Errors::Error, "OAuth flow failed: #{SecretScrubber.call(text: e.message)}"
        end

        # Returns true when the backend could not store the token unattended and
        # left a manual step for the user; false when the token was written.
        def persist_token(config, backend, client_id, token)
          write_profile_backend(config, backend, client_id)
          settings = merged_settings.call(config: config, profile: profile)
          written = token_persister.call(
            profile: profile, token: token, backend_name: backend.to_s, settings: settings,
          )
          output.puts("Wrote token to #{written[:location] || written[:source]}.")
          false
        rescue Tokens::Errors::ManualWriteRequired => e
          output.puts("Backend `#{backend}` needs a manual step:")
          # Print the message verbatim. Backends like Dashlane put the raw token
          # on its own line for copy/paste; a leading indent would corrupt it and
          # a user could paste an invalid (space-prefixed) token.
          output.puts(e.message)
          true
        end

        # Manual-write backends (Env, Dashlane) haven't stored the token yet at
        # this point, so claiming "Setup complete!" would send the user to a
        # `doctor` run that fails. Tailor the closing line to each case.
        def completion_message(manual_pending)
          verify = "verify with: ruby slack_status.rb doctor --profile #{profile}"
          if manual_pending
            "Almost done — complete the manual storage step above, then #{verify}"
          else
            "Setup complete! Verify with: ruby slack_status.rb doctor --profile #{profile}"
          end
        end

        def write_profile_backend(config, backend, client_id)
          config["profiles"] ||= {}
          config["profiles"][profile] ||= {}
          config["profiles"][profile]["storage_backend"] = backend.to_s

          global_id = config.dig("global", "oauth", "client_id")
          if presence(client_id) && client_id != global_id
            config["profiles"][profile]["oauth"] ||= {}
            config["profiles"][profile]["oauth"]["client_id"] = client_id
          end

          config_writer.call(config: config, path: config_path)
        end

        def config_path
          options[:config_path] || Tokens::Constants::DEFAULT_CONFIG_PATH
        end

        def profile
          options[:profile] || env["SLACK_STATUS_PROFILE"] || DEFAULT_PROFILE
        end

        def presence(value)
          return nil if value.nil?

          stripped = value.to_s.strip
          stripped.empty? ? nil : stripped
        end
      end
    end
  end
end
