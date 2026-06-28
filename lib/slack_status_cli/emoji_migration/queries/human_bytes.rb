module SlackStatusCli
  module EmojiMigration
    module Queries
      # Renders a byte count as a short human-readable size: whole bytes under
      # 1 KiB, then one decimal place for KB/MB/GB.
      class HumanBytes
        extend Callable

        KIB = 1024
        MIB = KIB * 1024
        GIB = MIB * 1024

        def initialize(bytes:)
          @bytes = bytes
        end

        def call
          return "#{@bytes} B" if @bytes < KIB
          return format("%.1f KB", @bytes / KIB.to_f) if @bytes < MIB
          return format("%.1f MB", @bytes / MIB.to_f) if @bytes < GIB

          format("%.1f GB", @bytes / GIB.to_f)
        end
      end
    end
  end
end
