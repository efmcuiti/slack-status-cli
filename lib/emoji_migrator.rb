require 'fileutils'
require 'json'
require 'net/http'
require 'uri'

# Downloads custom emoji image files from one Slack workspace into a local
# directory so they can be bulk-uploaded to another workspace via Slack's
# emoji admin page. Read-only against the source workspace API.
#
# Slack's `emoji.list` returns entries of two shapes:
#   "phoenix_ash"       => "https://emoji.slack-edge.com/T.../phoenix_ash/abc.png"
#   "phoenix_alias"     => "alias:phoenix_ash"
#
# Alias entries don't have their own image file and can't be recreated via
# Slack's web UI bulk-upload, so we record them in `aliases.json` next to the
# images for the user's reference.
class EmojiMigrator
  class Error < StandardError; end
  class MissingScope < Error; end

  CONCURRENCY = 6
  ALIAS_FILENAME = "aliases.json".freeze
  SKIPLIST_FILENAME = "skipped.json".freeze

  attr_reader :downloaded, :aliases, :skipped, :total_bytes

  def initialize(emoji_map:, out_dir:, filter: nil, logger: nil)
    @emoji_map = emoji_map || {}
    @out_dir = out_dir
    @filter_pattern = filter
    @logger = logger
    @downloaded = []
    @aliases = {}
    @skipped = []
    @total_bytes = 0
  end

  # Runs the migration. Returns self so callers can read counters off it.
  def run
    FileUtils.mkdir_p(@out_dir)

    entries = filtered_entries
    real_emoji = entries.reject { |_n, v| v.to_s.start_with?("alias:") }
    aliases    = entries.select { |_n, v| v.to_s.start_with?("alias:") }

    log "found #{entries.size} emoji#{entries.size == 1 ? "" : "s"} matching filter (#{real_emoji.size} images, #{aliases.size} aliases)"

    aliases.each { |name, target| @aliases[name] = target.sub(/^alias:/, "") }
    write_metadata_files

    download_in_parallel(real_emoji)

    self
  end

  # Resolves to a {name => {extension:, bytes:, path:}} hash for the caller's
  # use (test seams, summary rendering).
  def downloaded_details
    @downloaded.dup
  end

  private

  def filtered_entries
    return @emoji_map if @filter_pattern.nil? || @filter_pattern.empty?
    re = Regexp.new(@filter_pattern, Regexp::IGNORECASE)
    @emoji_map.select { |name, _| re.match?(name) }
  end

  def download_in_parallel(real_emoji)
    queue = Queue.new
    real_emoji.each { |pair| queue.push(pair) }
    mutex = Mutex.new

    workers = Array.new(CONCURRENCY) do
      Thread.new do
        loop do
          begin
            name, url = queue.pop(true)
          rescue ThreadError
            break
          end
          begin
            entry = download_one(name, url)
            mutex.synchronize do
              @downloaded << entry
              @total_bytes += entry[:bytes]
              log "  ✓ #{name}.#{entry[:extension]} (#{human_bytes(entry[:bytes])})"
            end
          rescue StandardError => e
            mutex.synchronize do
              @skipped << { name: name, url: url, reason: e.message }
              log "  ✗ #{name} skipped: #{e.message}"
            end
          end
        end
      end
    end
    workers.each(&:join)
  end

  def download_one(name, url)
    uri = URI(url)
    body =
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.read_timeout = 30
        resp = http.get(uri.request_uri)
        raise "HTTP #{resp.code}" unless resp.is_a?(Net::HTTPSuccess)
        resp.body
      end

    ext = extension_for(url, body)
    safe_name = sanitize_filename(name)
    path = File.join(@out_dir, "#{safe_name}.#{ext}")
    File.binwrite(path, body)

    { name: name, extension: ext, bytes: body.bytesize, path: path }
  end

  # Slack's emoji image URLs include a clean extension in the last path
  # segment (.png, .gif, .jpg). If something exotic shows up we fall back to
  # sniffing the first few bytes.
  def extension_for(url, body)
    from_url = File.extname(URI(url).path).delete_prefix(".").downcase
    return from_url if %w[png gif jpg jpeg webp].include?(from_url)

    case body[0, 8]
    when /\A\x89PNG/n then "png"
    when /\AGIF8/n    then "gif"
    when /\A\xFF\xD8\xFF/n then "jpg"
    else "bin"
    end
  end

  # Emoji names are already a restricted character set (a-z, 0-9, _, -, +)
  # per Slack, but defend against future surprises.
  def sanitize_filename(name)
    name.to_s.gsub(/[^a-zA-Z0-9_+\-]/, "_")
  end

  def write_metadata_files
    File.write(
      File.join(@out_dir, ALIAS_FILENAME),
      JSON.pretty_generate(@aliases),
    )
  end

  def finalize_skipped_file
    return if @skipped.empty?
    File.write(
      File.join(@out_dir, SKIPLIST_FILENAME),
      JSON.pretty_generate(@skipped),
    )
  end

  def human_bytes(n)
    return "#{n} B" if n < 1024
    return format("%.1f KB", n / 1024.0) if n < 1024 * 1024
    format("%.1f MB", n / 1024.0 / 1024.0)
  end

  def log(message)
    return unless @logger
    @logger.call(message)
  end
end
