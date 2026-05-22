require "tmpdir"

# Yields a `config.yml` path inside a fresh temporary directory that is removed
# automatically when the block returns or raises. Domain specs that touch the
# CLI's on-disk config use this helper instead of writing to the real
# `~/.slack-status-cli/` tree.
module TmpConfig
  def with_tmp_config(&block)
    Dir.mktmpdir("slack-status-cli-config") do |dir|
      path = File.join(dir, "config.yml")
      block.call(path: path, dir: dir)
    end
  end
end
