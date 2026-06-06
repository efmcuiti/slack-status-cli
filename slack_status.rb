#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.join(__dir__, "lib"))

require 'json'
require 'optparse'

require 'cli_prompt'
require 'token_resolver'
require 'slack_status_cli'

RESERVED_MODES = %i[myth lunch break clear musical_myth].freeze
SUBCOMMANDS    = %w[setup doctor config profiles].freeze
BACKENDS       = TokenResolver::SUPPORTED_BACKENDS

def parse_global_flags(argv)
  options = {
    profile: nil,
    token: nil,
    config_path: nil,
    verbose: false,
    non_interactive: false,
    rotate: false,
    global: false,
    backend: nil,
    client_id: nil,
    client_secret: nil,
    from: nil,
    to: nil,
    out: nil,
    filter: nil,
    open_browser: true,
  }

  parser = OptionParser.new do |o|
    o.banner = "Usage: ruby slack_status.rb [options] <command> [args]"
    o.separator ""
    o.separator "Commands: setup, doctor, config get|set, profiles list, migrate-emojis,"
    o.separator "          plus any mode (myth, lunch, break, clear, musical_myth, custom)"
    o.separator ""
    o.on("--profile NAME", "Profile name (default: $SLACK_STATUS_PROFILE or 'default')") { |v| options[:profile] = v }
    o.on("--token TOKEN", "Use this token directly (highest precedence)") { |v| options[:token] = v }
    o.on("--config PATH", "Path to config.yml (default: ~/.config/slack-status-cli/config.yml)") { |v| options[:config_path] = v }
    o.on("--verbose", "Print token source to stderr") { options[:verbose] = true }
    o.on("--non-interactive", "Fail instead of prompting") { options[:non_interactive] = true }
    o.on("--rotate", "(setup) Overwrite an existing token") { options[:rotate] = true }
    o.on("--global", "(setup) Configure global defaults only") { options[:global] = true }
    o.on("--backend NAME", BACKENDS, "(setup) Storage backend: #{BACKENDS.join('|')}") { |v| options[:backend] = v }
    o.on("--client-id ID", "(setup) Slack App client_id") { |v| options[:client_id] = v }
    o.on("--client-secret SECRET", "(setup) Slack App client_secret (prefer prompt)") { |v| options[:client_secret] = v }
    o.on("--from PROFILE", "(migrate-emojis) Source profile to download emojis from") { |v| options[:from] = v }
    o.on("--to PROFILE", "(migrate-emojis) Destination profile (used to derive admin URL)") { |v| options[:to] = v }
    o.on("--out DIR", "(migrate-emojis) Output directory (default: ./emoji-export-<from>-<timestamp>)") { |v| options[:out] = v }
    o.on("--filter REGEX", "(migrate-emojis) Only download emoji whose name matches REGEX (case-insensitive)") { |v| options[:filter] = v }
    o.on("--no-open", "(migrate-emojis) Do not open the destination admin URL automatically") { options[:open_browser] = false }
    o.on("-h", "--help", "Show this help") { puts o; exit 0 }
  end

  # `permute!` (not `order!`) so flags can appear anywhere — before or after
  # the subcommand. Otherwise `slack_status.rb setup --profile foo` silently
  # drops `--profile foo` because OptionParser stops at the first non-option
  # (`setup`).
  parser.permute!(argv)
  options
end

def build_resolver(options)
  TokenResolver.new(
    profile: options[:profile],
    cli_token: options[:token],
    config_path: options[:config_path],
    verbose: options[:verbose],
  )
end

def run_status_mode(command, rest_args, options)
  mode = command&.to_sym
  if mode == :musical_myth
    text = nil
    emoji = nil
    expiration = nil
  else
    text = rest_args[0]
    emoji = rest_args[1]
    expiration = rest_args[2]
  end

  resolver = build_resolver(options)
  token_info =
    begin
      resolver.resolve
    rescue TokenResolver::NotFoundError => e
      CliPrompt.fail("Could not resolve a Slack token.")
      e.message.each_line { |line| warn "   #{line.chomp}" }
      exit 1
    end

  token = token_info[:token]
  install_signal_handlers(token)
  SlackStatusCli::Slack::Commands::UpdateStatus.call(
    token: token,
    mode: mode,
    text: text,
    emoji: emoji,
    expiration: expiration,
  )
end

def install_signal_handlers(token)
  shutdown_requested = false
  %w[INT TERM].each do |sig|
    trap(sig) do
      shutdown_requested = true
      exit
    end
  end

  at_exit do
    next unless shutdown_requested && token
    puts "\nStopping Slack client… sending goodbye to Music ❤️"
    SlackStatusCli::Slack::Commands::ClearStatus.call(token: token)
  end
end

# --- subcommands ---

def run_setup(options)
  require 'oauth_helper'

  profile = options[:profile] || ENV["SLACK_STATUS_PROFILE"] || TokenResolver::DEFAULT_PROFILE
  config_path = options[:config_path] || TokenResolver::DEFAULT_CONFIG_PATH
  config = TokenResolver.load_config(config_path)
  config["global"] ||= {}
  config["profiles"] ||= {}

  total_steps = options[:global] ? 2 : 4

  CliPrompt.step(1, total_steps, "Slack App configuration")
  client_id = resolve_client_id(options, config, profile)
  client_secret = options[:global] ? nil : resolve_client_secret(options, config, profile, client_id)

  CliPrompt.step(2, total_steps, "Choose a token storage backend")
  backend = resolve_backend(options, config, profile)
  CliPrompt.done("Backend: #{backend}")

  if options[:global]
    persist_global_defaults(config, config_path, client_id: client_id, backend: backend)
    CliPrompt.done("Global defaults saved to #{config_path}.")
    return
  end

  if profile_has_token?(profile, config_path) && !options[:rotate]
    if CliPrompt.ask_yes_no("Profile '#{profile}' already has a token. Overwrite?", default: :no, non_interactive: options[:non_interactive])
      options[:rotate] = true
    else
      CliPrompt.skip("Keeping existing token. Use --rotate to force.")
      return
    end
  end

  CliPrompt.step(3, total_steps, "OAuth install")
  helper = OAuthHelper.new(client_id: client_id, client_secret: client_secret)
  CliPrompt.browser("Opening #{helper.authorize_url[0, 80]}… in your browser.")
  CliPrompt.info("Listening on #{helper.redirect_uri} (2 min timeout)…")
  open_in_browser(helper.authorize_url)

  result =
    begin
      helper.run
    rescue OAuthHelper::Error => e
      CliPrompt.fail("OAuth flow failed: #{CliPrompt.scrub_secrets(e.message)}")
      exit 1
    end

  CliPrompt.done("Received authorization code; exchanging for user token…")
  CliPrompt.done("Got #{redacted_token(result[:token])} (scope=#{result[:scope]}, team=#{result[:team_name]})")

  CliPrompt.step(4, total_steps, "Persist the token")
  persist_profile_token(
    config,
    config_path,
    profile: profile,
    backend: backend,
    token: result[:token],
    client_id: client_id,
  )
end

def resolve_client_id(options, config, profile)
  return options[:client_id] if options[:client_id] && !options[:client_id].empty?

  # Profile-level client_id wins over global. This is how multi-workspace
  # setups work without enabling Slack App Distribution: one internal app
  # per workspace, each with its own client_id stored under its profile.
  profile_existing = config.dig("profiles", profile, "oauth", "client_id")
  global_existing  = config.dig("global", "oauth", "client_id")
  existing = profile_existing || global_existing
  scope = profile_existing ? "profile '#{profile}'" : "global"

  if existing && !existing.empty?
    if CliPrompt.ask_yes_no("Found #{scope} client_id ending in #{CliPrompt.redacted(existing)}. Reuse it?", default: :yes, non_interactive: options[:non_interactive])
      CliPrompt.done("Using #{scope} client_id ending in #{CliPrompt.redacted(existing)}.")
      return existing
    end
  end

  # First-time setup (or user declined to reuse): show where to find the
  # credentials before prompting so the input has context.
  print_app_creation_instructions(options)

  value = CliPrompt.ask("Enter Client ID (from Basic Information):", non_interactive: options[:non_interactive])
  raise "Client ID is required" if value.nil? || value.empty?
  value
end

def print_app_creation_instructions(options)
  CliPrompt.manual(
    <<~INSTR,
      Where to find your Client ID + Client Secret:
        1) Open https://api.slack.com/apps?new_app=1
        2) Pick "From a manifest", then pick your workspace.
        3) Paste the contents of docs/slack-app-manifest.yml and confirm.
        4) On the new app's "Basic Information" page, scroll to "App Credentials":
           - Client ID looks like 1234567890123.0987654321098
           - Click "Show" next to Client Secret to reveal it.
        5) The manifest pre-fills the OAuth redirect URL; double-check it under
           "OAuth & Permissions" → "Redirect URLs": http://localhost:53682/callback
    INSTR
    non_interactive: options[:non_interactive],
  )
end

def resolve_client_secret(options, config, profile, client_id)
  return options[:client_secret] if options[:client_secret] && !options[:client_secret].empty?

  # Profile-level secret_ref wins over global, mirroring client_id semantics
  # so a per-workspace app can carry its own Dashlane / env reference.
  secret_ref = config.dig("profiles", profile, "oauth", "client_secret_ref") ||
               config.dig("global", "oauth", "client_secret_ref")
  if secret_ref && !secret_ref.empty?
    value = read_secret_ref(secret_ref)
    if value
      CliPrompt.done("Resolved client_secret from #{secret_ref}.")
      return value
    end
    CliPrompt.warn("client_secret_ref #{secret_ref} did not resolve; will prompt.")
  end

  CliPrompt.ask("Enter Client Secret (from Basic Information; input hidden):", secret: true, non_interactive: options[:non_interactive])
end

# Resolves a `client_secret_ref` of the form `dl://...`, `env:VAR`, or `file:/path`.
def read_secret_ref(ref)
  case ref
  when /\Aenv:(.+)\z/
    value = ENV[$1]
    value && !value.empty? ? value : nil
  when /\Adl:\/\//
    require 'open3'
    stdout, _stderr, status = Open3.capture3("dcli", "read", ref)
    return nil unless status.success?
    stripped = stdout.strip
    stripped.empty? ? nil : stripped
  when /\Afile:(.+)\z/
    path = File.expand_path($1)
    return nil unless File.exist?(path)
    value = File.read(path).strip
    value.empty? ? nil : value
  else
    nil
  end
rescue Errno::ENOENT
  nil
end

def resolve_backend(options, config, profile)
  return options[:backend] if options[:backend]

  default = config.dig("profiles", profile, "storage_backend") ||
            config.dig("global", "storage_backend") ||
            "dashlane"

  if CliPrompt.ask_yes_no("Use the default backend `#{default}`?", default: :yes, non_interactive: options[:non_interactive])
    return default
  end

  CliPrompt.select("Available backends:", options: BACKENDS, default: default, non_interactive: options[:non_interactive])
end

def profile_has_token?(profile, config_path)
  TokenResolver.new(profile: profile, config_path: config_path).resolve
  true
rescue TokenResolver::NotFoundError
  false
end

def persist_global_defaults(config, config_path, client_id:, backend:)
  config["global"] ||= {}
  config["global"]["oauth"] ||= {}
  config["global"]["oauth"]["client_id"] = client_id
  config["global"]["storage_backend"] = backend
  TokenResolver.write_config(config, config_path)
end

def persist_profile_token(config, config_path, profile:, backend:, token:, client_id: nil)
  config["profiles"] ||= {}
  config["profiles"][profile] ||= {}
  config["profiles"][profile]["storage_backend"] = backend

  # Store the client_id under the profile only when it diverges from the
  # global default. Same value as global → keep it as a single source of truth.
  # Different value (e.g., a per-workspace Slack App) → pin it on the profile
  # so future setup/doctor runs use the right app.
  global_id = config.dig("global", "oauth", "client_id")
  if client_id && !client_id.empty? && client_id != global_id
    config["profiles"][profile]["oauth"] ||= {}
    config["profiles"][profile]["oauth"]["client_id"] = client_id
  end

  TokenResolver.write_config(config, config_path)

  resolver = TokenResolver.new(profile: profile, config_path: config_path)
  begin
    label = resolver.write_token(token, backend_name: backend)
    CliPrompt.secret_written("Wrote token to #{label}.")
    CliPrompt.done("Setup complete. Verify with: ruby slack_status.rb doctor --profile #{profile}")
  rescue TokenResolver::ManualWriteRequired => e
    CliPrompt.warn("Backend `#{backend}` needs a manual step:")
    e.message.each_line { |line| puts "   #{line.chomp}" }
    CliPrompt.done("Once stored, verify with: ruby slack_status.rb doctor --profile #{profile}")
  end
end

def open_in_browser(url)
  return unless RUBY_PLATFORM.include?("darwin")
  system("open", url)
end

def redacted_token(token)
  return "<token>" if token.nil? || token.empty?
  "#{token[0, 5]}…#{token[-4, 4]}"
end

def run_doctor(options)
  resolver = build_resolver(options)
  token_info =
    begin
      resolver.resolve
    rescue TokenResolver::NotFoundError => e
      CliPrompt.fail("No token resolved for profile '#{resolver.profile}'.")
      e.message.each_line { |line| warn "   #{line.chomp}" }
      exit 1
    end

  CliPrompt.info("source : #{token_info[:source]}")
  CliPrompt.info("profile: #{token_info[:profile]}")
  CliPrompt.info("token  : #{redacted_token(token_info[:token])}")

  response =
    begin
      SlackStatusCli::Slack::Queries::AuthTest.call(token: token_info[:token])
    rescue StandardError => e
      CliPrompt.fail("auth.test failed: #{CliPrompt.scrub_secrets(e.message)}")
      exit 1
    end

  if response["ok"]
    CliPrompt.done("auth.test ok — workspace=#{response['team']} user=#{response['user']} url=#{response['url']}")
  else
    CliPrompt.fail("Slack rejected token: #{response['error']}")
    hint = doctor_hint(response['error'])
    CliPrompt.info(hint) if hint
    exit 1
  end
end

def run_migrate_emojis(options)
  require 'emoji_migrator'
  require 'time'

  from = options[:from]
  abort "migrate-emojis requires --from <profile>" if from.nil? || from.empty?
  to = options[:to]

  source_resolver = TokenResolver.new(
    profile: from,
    cli_token: nil,
    config_path: options[:config_path],
    verbose: options[:verbose],
  )
  source_token =
    begin
      source_resolver.resolve[:token]
    rescue TokenResolver::NotFoundError => e
      CliPrompt.fail("Could not resolve a token for source profile '#{from}'.")
      e.message.each_line { |line| warn "   #{line.chomp}" }
      exit 1
    end

  CliPrompt.step(1, 4, "Listing custom emojis on '#{from}'")
  emoji_response =
    begin
      SlackStatusCli::Slack::Queries::EmojiList.call(token: source_token)
    rescue StandardError => e
      CliPrompt.fail("emoji.list failed: #{CliPrompt.scrub_secrets(e.message)}")
      exit 1
    end

  unless emoji_response["ok"]
    case emoji_response["error"]
    when "missing_scope"
      CliPrompt.fail("Token for '#{from}' is missing the `emoji:read` scope.")
      CliPrompt.info("Re-run setup to grant it:")
      CliPrompt.info("  ruby slack_status.rb setup --profile #{from} --rotate")
      CliPrompt.info("(The shipped manifest already declares the scope; re-installing the app re-prompts you for consent.)")
    else
      CliPrompt.fail("Slack rejected emoji.list: #{emoji_response["error"]}")
    end
    exit 1
  end

  emoji_map = emoji_response["emoji"] || {}
  CliPrompt.done("Found #{emoji_map.size} entr#{emoji_map.size == 1 ? "y" : "ies"}.")

  out_dir = options[:out] || "./emoji-export-#{from}-#{Time.now.strftime("%Y%m%d-%H%M%S")}"
  CliPrompt.step(2, 4, "Downloading images to #{out_dir}")
  migrator = EmojiMigrator.new(
    emoji_map: emoji_map,
    out_dir: out_dir,
    filter: options[:filter],
    logger: ->(msg) { CliPrompt.info(msg) },
  ).run

  CliPrompt.done(
    "Downloaded #{migrator.downloaded.size} image#{migrator.downloaded.size == 1 ? "" : "s"} " \
    "(#{format("%.1f KB", migrator.total_bytes / 1024.0)}), " \
    "#{migrator.aliases.size} alias#{migrator.aliases.size == 1 ? "" : "es"} (see aliases.json), " \
    "#{migrator.skipped.size} skipped."
  )

  admin_url = nil
  if to && !to.empty?
    CliPrompt.step(3, 4, "Resolving destination workspace from profile '#{to}'")
    admin_url = resolve_admin_url(options, to)
    if admin_url
      CliPrompt.done("Destination emoji admin: #{admin_url}")
    else
      CliPrompt.skip("Could not derive destination admin URL; skipping browser step.")
    end
  end

  CliPrompt.step(4, 4, "Next: bulk-upload to your destination workspace")
  CliPrompt.manual(<<~MSG.strip, non_interactive: options[:non_interactive])
    Slack does not expose an emoji-upload API for non-Enterprise workspaces,
    so the last mile is a one-time drag-and-drop:

      1. Open #{admin_url || "<your-workspace>.slack.com/customize/emoji"}
      2. Click "Add Custom Emoji" -> "Upload Image".
      3. Drag every image from:
           #{File.expand_path(out_dir)}
         (Slack's emoji admin accepts multi-file drag-and-drop.)
      4. Aliases (see aliases.json in the same folder) must be recreated
         manually: "Add Custom Emoji" -> "Add Alias".

    Press Enter when you're done (or Ctrl-C to abort).
  MSG

  if admin_url && options[:open_browser]
    open_in_browser(admin_url)
  end
end

# Calls auth.test against the destination profile to derive
# https://<team-subdomain>.slack.com/customize/emoji. Returns nil on any
# failure (network, missing profile, rejected token) — caller treats that as
# "skip the browser step".
def resolve_admin_url(options, to_profile)
  resolver = TokenResolver.new(
    profile: to_profile,
    cli_token: nil,
    config_path: options[:config_path],
    verbose: options[:verbose],
  )
  token = resolver.resolve[:token]
  response = SlackStatusCli::Slack::Queries::AuthTest.call(token: token)
  return nil unless response["ok"]
  url = response["url"].to_s.sub(/\/+\z/, "")
  return nil if url.empty?
  "#{url}/customize/emoji"
rescue StandardError
  nil
end

def doctor_hint(error_code)
  case error_code
  when "not_authed", "invalid_auth", "token_revoked"
    "Re-run: ruby slack_status.rb setup --profile <name> --rotate"
  when "missing_scope"
    "Your token is missing `users.profile:write`. Re-run setup and accept the manifest scopes."
  when "account_inactive"
    "The Slack user owning this token is deactivated. Use a different account."
  when "rate_limited"
    "Slack is rate-limiting this token. Retry later."
  end
end

def run_config(args, options)
  sub = args.shift
  config_path = options[:config_path] || TokenResolver::DEFAULT_CONFIG_PATH

  case sub
  when "get"
    key = args.shift or abort "Usage: config get <dotted.key>"
    config = TokenResolver.load_config(config_path)
    value = dotted_get(config, key)
    if value.nil?
      warn "(unset)"
      exit 1
    end
    puts value.is_a?(Hash) || value.is_a?(Array) ? JSON.pretty_generate(value) : value
  when "set"
    key = args.shift or abort "Usage: config set <dotted.key> <value>"
    value = args.shift
    abort "Usage: config set <dotted.key> <value>" if value.nil?
    config = TokenResolver.load_config(config_path)
    dotted_set!(config, key, coerce_scalar(value))
    TokenResolver.write_config(config, config_path)
    CliPrompt.done("set #{key} = #{value}")
  when "path"
    puts config_path
  when nil, "help", "-h", "--help"
    puts <<~HELP
      config get <dotted.key>          # e.g. config get global.storage_backend
      config set <dotted.key> <value>  # e.g. config set global.storage_backend keychain
      config path                      # print the active config file path
    HELP
  else
    abort "Unknown config subcommand: #{sub}"
  end
end

def run_profiles(args, options)
  sub = args.shift || "list"
  config_path = options[:config_path] || TokenResolver::DEFAULT_CONFIG_PATH
  config = TokenResolver.load_config(config_path)

  case sub
  when "list"
    profiles = (config["profiles"] || {}).keys
    if profiles.empty?
      puts "(no profiles configured; run: ruby slack_status.rb setup --profile <name>)"
      return
    end
    global_backend = config.dig("global", "storage_backend") || "(unset)"
    puts "Global default backend: #{global_backend}"
    profiles.each do |name|
      backend = config.dig("profiles", name, "storage_backend") || global_backend
      puts "  - #{name}  (backend=#{backend})"
    end
  else
    abort "Unknown profiles subcommand: #{sub}"
  end
end

def dotted_get(hash, key)
  key.to_s.split(".").reduce(hash) do |memo, part|
    break nil unless memo.is_a?(Hash)
    memo[part]
  end
end

def dotted_set!(hash, key, value)
  parts = key.to_s.split(".")
  last = parts.pop
  cursor = parts.reduce(hash) do |memo, part|
    memo[part] = {} unless memo[part].is_a?(Hash)
    memo[part]
  end
  cursor[last] = value
end

def coerce_scalar(str)
  case str
  when "true" then true
  when "false" then false
  when "null", "nil" then nil
  when /\A-?\d+\z/ then Integer(str)
  else str
  end
end

if __FILE__ == $0
  options = parse_global_flags(ARGV)
  command = ARGV.shift

  case command
  when "setup"          then run_setup(options)
  when "doctor"         then run_doctor(options)
  when "config"         then run_config(ARGV, options)
  when "profiles"       then run_profiles(ARGV, options)
  when "migrate-emojis" then run_migrate_emojis(options)
  else
    run_status_mode(command, ARGV, options)
  end
end
