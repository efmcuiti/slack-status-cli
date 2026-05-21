require 'fileutils'
require 'json'
require 'open3'
require 'yaml'

# Resolves a Slack user token for the current profile by walking a fixed
# precedence chain (CLI flag -> profile-scoped env -> config-driven backend ->
# legacy SLACK_SECRET_TOKEN). Also serves as the read/write interface used by
# the `setup` and `config` subcommands.
class TokenResolver
  class Error < StandardError; end
  class NotFoundError < Error; end
  class ConfigError < Error; end
  class ManualWriteRequired < Error; end
  class WriteError < Error; end

  DEFAULT_CONFIG_PATH = File.expand_path("~/.config/slack-status-cli/config.yml").freeze
  DEFAULT_TOKEN_DIR = File.expand_path("~/.config/slack-status-cli/tokens").freeze
  DEFAULT_PROFILE = "default".freeze
  KEYCHAIN_SERVICE = "slack-status-cli".freeze
  LEGACY_ENV_VAR = "SLACK_SECRET_TOKEN".freeze
  SUPPORTED_BACKENDS = %w[dashlane keychain file env].freeze

  attr_reader :profile, :config_path

  def initialize(profile: nil, cli_token: nil, config_path: nil, verbose: false)
    @profile = (profile || ENV["SLACK_STATUS_PROFILE"] || DEFAULT_PROFILE).to_s
    @cli_token = cli_token
    @config_path = config_path || DEFAULT_CONFIG_PATH
    @verbose = verbose
  end

  # Walks the precedence chain and returns the first non-empty token found.
  # @return [Hash] { token:, source:, profile: }
  # @raise [NotFoundError] when nothing resolves
  #
  # Precedence (highest -> lowest):
  #   1. --token CLI flag
  #   2. SLACK_STATUS_TOKEN_<PROFILE> env var
  #   3. Backend configured for the active profile (profile -> global)
  #   4. SLACK_SECRET_TOKEN (legacy) — ONLY when the active profile is `default`
  #      AND no profile-specific backend is configured. This protects users who
  #      run with `--profile work` from getting their `SLACK_SECRET_TOKEN`
  #      (which may belong to a different workspace) silently injected.
  def resolve
    if non_empty?(@cli_token)
      return success(@cli_token, "cli:--token")
    end

    profile_env_key = profile_env_var_name(@profile)
    if non_empty?(ENV[profile_env_key])
      return success(ENV[profile_env_key], "env:#{profile_env_key}")
    end

    cfg = load_config
    profile_configured = profile_explicitly_configured?(cfg)

    backend = build_backend(config: cfg)
    tried_backend = nil
    if backend
      tried_backend = backend
      token = backend.read
      return success(token, backend.source_label) if non_empty?(token)
    end

    # Legacy fallback is profile-agnostic; restrict it to the default profile
    # with no backend configured to prevent cross-workspace token leakage.
    legacy_eligible = @profile == DEFAULT_PROFILE && !profile_configured && backend.nil?
    if legacy_eligible && non_empty?(ENV[LEGACY_ENV_VAR])
      return success(ENV[LEGACY_ENV_VAR], "env:#{LEGACY_ENV_VAR}")
    end

    raise NotFoundError, friendly_not_found_message(
      tried_backend: tried_backend,
      profile_configured: profile_configured,
    )
  end

  # Returns the merged settings hash (global <- profile) for the active
  # profile, without reading any secrets.
  def merged_settings
    cfg = load_config
    global = cfg["global"] || {}
    profile_cfg = (cfg.dig("profiles", @profile) || {})
    deep_merge(global, profile_cfg)
  end

  # Persists a token via the backend selected by merged settings. Returns the
  # backend's source label on success. Raises ManualWriteRequired when the
  # backend cannot write programmatically (instructions are in the message).
  def write_token(token, backend_name: nil)
    backend = build_backend(forced_backend: backend_name)
    raise WriteError, "No backend configured for profile #{@profile}" unless backend
    backend.write(token)
    backend.source_label
  end

  def load_config
    self.class.load_config(@config_path)
  end

  def self.load_config(path = DEFAULT_CONFIG_PATH)
    return {} unless File.exist?(path)
    YAML.safe_load(File.read(path), permitted_classes: [], aliases: false) || {}
  rescue Psych::Exception => e
    raise ConfigError, "Failed to parse #{path}: #{e.message}"
  end

  def self.write_config(config, path = DEFAULT_CONFIG_PATH)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, YAML.dump(deep_stringify(config)))
    File.chmod(0o600, path)
    path
  end

  def self.profile_env_var_name(profile)
    "SLACK_STATUS_TOKEN_#{sanitize_profile_for_env(profile)}"
  end

  def self.sanitize_profile_for_env(profile)
    profile.to_s.upcase.gsub(/[^A-Z0-9_]/, "_")
  end

  def self.deep_merge(a, b)
    return b.dup if a.nil? || a.empty?
    return a.dup if b.nil? || b.empty?
    a.merge(b) do |_key, av, bv|
      if av.is_a?(Hash) && bv.is_a?(Hash)
        deep_merge(av, bv)
      else
        bv
      end
    end
  end

  def self.deep_stringify(obj)
    case obj
    when Hash then obj.each_with_object({}) { |(k, v), h| h[k.to_s] = deep_stringify(v) }
    when Array then obj.map { |v| deep_stringify(v) }
    else obj
    end
  end

  private

  def profile_env_var_name(profile)
    self.class.profile_env_var_name(profile)
  end

  def deep_merge(a, b)
    self.class.deep_merge(a, b)
  end

  def non_empty?(value)
    !value.nil? && !value.to_s.strip.empty?
  end

  def success(token, source)
    log_source(source)
    { token: token.to_s.strip, source: source, profile: @profile }
  end

  def log_source(source)
    return unless @verbose
    warn "[slack-status-cli] token resolved from #{source} (profile=#{@profile})"
  end

  def build_backend(forced_backend: nil, config: nil)
    settings = config ? merge_settings_from(config) : merged_settings
    backend_name = (forced_backend || settings["storage_backend"] || infer_default_backend(settings))&.to_s
    return nil unless backend_name

    klass = backend_class(backend_name)
    raise ConfigError, "Unknown storage_backend '#{backend_name}' (supported: #{SUPPORTED_BACKENDS.join(', ')})" unless klass

    klass.new(profile: @profile, settings: settings)
  end

  def merge_settings_from(cfg)
    global = cfg["global"] || {}
    profile_cfg = (cfg.dig("profiles", @profile) || {})
    deep_merge(global, profile_cfg)
  end

  def profile_explicitly_configured?(cfg)
    block = cfg.dig("profiles", @profile)
    block.is_a?(Hash) && !block.empty?
  end

  def infer_default_backend(settings)
    return nil if settings.nil? || settings.empty?
    return "dashlane" if settings["token_ref"]
    nil
  end

  def backend_class(name)
    case name
    when "dashlane" then DashlaneBackend
    when "keychain" then KeychainBackend
    when "file" then FileBackend
    when "env" then EnvBackend
    end
  end

  def friendly_not_found_message(tried_backend: nil, profile_configured: false)
    lines = ["No Slack token found for profile '#{@profile}'."]

    if tried_backend
      lines << "Tried #{tried_backend.source_label} but it returned no token."
      hint = tried_backend.not_found_hint
      hint.each_line { |l| lines << "  #{l.chomp}" } if hint
    elsif !profile_configured && @profile != DEFAULT_PROFILE
      lines << "Profile '#{@profile}' is not configured in #{@config_path}."
    end

    lines << ""
    lines << "Fix one of:"
    lines << "  1. ruby slack_status.rb setup --profile #{@profile}"
    lines << "  2. export #{profile_env_var_name(@profile)}=xoxp-... in your shell"
    lines << "  3. ruby slack_status.rb --token xoxp-... --profile #{@profile} <mode>"

    if non_empty?(ENV[LEGACY_ENV_VAR]) && (@profile != DEFAULT_PROFILE || profile_configured)
      lines << ""
      lines << "Note: SLACK_SECRET_TOKEN is set but intentionally ignored for"
      lines << "profile '#{@profile}' to avoid sending a token from a different"
      lines << "workspace. The legacy fallback only applies to the `default`"
      lines << "profile when no backend is configured."
    end

    lines.join("\n")
  end

  class Backend
    attr_reader :profile, :settings, :last_error

    def initialize(profile:, settings: {})
      @profile = profile
      @settings = settings || {}
      @last_error = nil
    end

    def read
      raise NotImplementedError
    end

    def write(_token)
      raise NotImplementedError
    end

    def source_label
      "#{name}:#{location}"
    end

    def name
      self.class.name.split("::").last.sub(/Backend$/, "").downcase
    end

    def location
      ""
    end

    # Backends override to explain WHY their read returned nil, including how
    # the user can fix it. Surfaced by TokenResolver::NotFoundError.
    def not_found_hint
      nil
    end
  end

  class DashlaneBackend < Backend
    # Uses `dcli note --output json 'title=<title>'` instead of the
    # `dcli read dl://<title>` URL form because the URL parser treats `/` as
    # the title/field separator, which breaks any title containing a slash
    # (e.g. `slack-status-cli/<profile>-token`).
    def read
      stdout, stderr, status = Open3.capture3(
        "dcli", "note", "--output", "json", "title=#{title}"
      )
      unless status.success?
        @last_error = strip_ansi(stderr).strip
        return nil
      end

      notes =
        begin
          JSON.parse(stdout)
        rescue JSON::ParserError => e
          @last_error = "dcli returned non-JSON output (#{e.message})"
          return nil
        end

      if notes.nil? || notes.empty?
        @last_error = "no Secure Note matches title=#{title} (local vault may be stale; try `dcli sync`)"
        return nil
      end

      content = notes.first["content"].to_s.strip
      if content.empty?
        @last_error = "Secure Note '#{title}' exists but its content is empty"
        return nil
      end
      content
    rescue Errno::ENOENT
      @last_error = "`dcli` not found in PATH"
      nil
    end

    def not_found_hint
      case @last_error
      when /no Secure Note matches/
        <<~HINT.strip
          No Secure Note titled '#{title}' was found in your local Dashlane vault.
          If you just created the note, refresh the local cache:
            dcli sync
          If the note doesn't exist yet, create it with:
            1. Open the Dashlane app.
            2. Add a Secure Note titled EXACTLY: #{title}
            3. Paste your Slack user token (xoxp-...) into the content field.
          To re-print the token and title, run:
            ruby slack_status.rb setup --profile #{profile} --rotate
        HINT
      when /content is empty/
        "Secure Note '#{title}' exists but its content is empty. Paste your xoxp-... token into it."
      when "`dcli` not found in PATH"
        "Install the Dashlane CLI: brew install dashlane/tap/dashlane-cli"
      when nil, ""
        nil
      else
        "dcli error: #{@last_error}"
      end
    end

    def write(token)
      # `dcli` personal does not expose a generic write API; instruct the user
      # to add the secret to their vault manually. The token itself is never
      # echoed back to stdout.
      raise ManualWriteRequired, <<~MSG.strip
        Dashlane CLI does not support unattended writes. Add the token manually:
          1. Open the Dashlane app (or run `dcli sync`).
          2. Create a Secure Note titled exactly: #{title}
          3. Paste the token (printed once below) into the content field.
          4. Re-run: ruby slack_status.rb doctor --profile #{profile}

        Token (copy now, it will not be shown again):
        #{token}
      MSG
    end

    def location
      token_ref
    end

    def token_ref
      ref = settings["token_ref"]
      return ref if ref && !ref.to_s.strip.empty?
      "dl://#{title_prefix}/#{profile}-token"
    end

    private

    def title
      token_ref.sub(/^dl:\/\//, "")
    end

    def title_prefix
      (settings.dig("backend_options", "dashlane", "title_prefix") || "slack-status-cli")
    end

    def strip_or_nil(value)
      stripped = value.to_s.strip
      stripped.empty? ? nil : stripped
    end

    def strip_ansi(value)
      value.to_s.gsub(/\e\[[0-9;]*m/, "")
    end
  end

  class KeychainBackend < Backend
    def read
      stdout, stderr, status = Open3.capture3(
        "security", "find-generic-password", "-s", service, "-a", account, "-w"
      )
      unless status.success?
        @last_error = stderr.to_s.strip
        return nil
      end
      stripped = stdout.to_s.strip
      stripped.empty? ? nil : stripped
    rescue Errno::ENOENT
      @last_error = "`security` not found in PATH (macOS only)"
      nil
    end

    def not_found_hint
      if @last_error&.include?("could not be found")
        "No Keychain item for service=#{service} account=#{account}. Re-run setup --profile #{profile} --rotate."
      elsif @last_error == "`security` not found in PATH (macOS only)"
        @last_error
      end
    end

    def write(token)
      stdout, stderr, status = Open3.capture3(
        "security", "add-generic-password",
        "-s", service, "-a", account, "-w", token, "-U"
      )
      return if status.success?
      raise WriteError, "security add-generic-password failed: #{stderr.strip.empty? ? stdout.strip : stderr.strip}"
    rescue Errno::ENOENT
      raise WriteError, "`security` not found in PATH; Keychain backend requires macOS."
    end

    def location
      "#{service}/#{account}"
    end

    private

    def service
      settings.dig("backend_options", "keychain", "service") || KEYCHAIN_SERVICE
    end

    def account
      settings.dig("backend_options", "keychain", "account") || profile
    end
  end

  class FileBackend < Backend
    def read
      unless File.exist?(path)
        @last_error = "file does not exist"
        return nil
      end
      unless permissions_ok?
        @last_error = "permissions too open"
        return nil
      end
      stripped = File.read(path).strip
      stripped.empty? ? nil : stripped
    end

    def not_found_hint
      case @last_error
      when "file does not exist" then "Token file not found at #{path}. Re-run setup --profile #{profile} --rotate."
      when "permissions too open" then "Token file #{path} has overly permissive permissions. Run: chmod 600 #{path}"
      end
    end

    def write(token)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "#{token}\n")
      File.chmod(0o600, path)
    end

    def location
      path
    end

    private

    def path
      override = settings.dig("backend_options", "file", "path")
      return File.expand_path(override) if override
      File.join(DEFAULT_TOKEN_DIR, profile)
    end

    # Refuses to read a token file with group/other readable bits set, so a
    # misconfigured permission doesn't silently leak the secret.
    def permissions_ok?
      mode = File.stat(path).mode & 0o777
      return true if (mode & 0o077).zero?
      warn "[slack-status-cli] refusing to read #{path}: permissions #{mode.to_s(8)} are too open (chmod 600)."
      false
    end
  end

  class EnvBackend < Backend
    def read
      key = env_key
      value = ENV[key]
      if value.nil? || value.strip.empty?
        @last_error = "env var #{key} is empty or unset"
        return nil
      end
      value.strip
    end

    def not_found_hint
      "Export #{env_key}=xoxp-... in your shell, then start a new shell."
    end

    def write(_token)
      raise ManualWriteRequired, <<~MSG.strip
        Env backend can't persist tokens automatically.
        Add this to your shell profile (~/.zshrc, ~/.bash_profile, etc.):
          export #{env_key}=xoxp-...
        Then start a new shell and re-run: ruby slack_status.rb doctor --profile #{profile}
      MSG
    end

    def location
      env_key
    end

    private

    def env_key
      settings.dig("backend_options", "env", "var") ||
        TokenResolver.profile_env_var_name(profile)
    end
  end
end
