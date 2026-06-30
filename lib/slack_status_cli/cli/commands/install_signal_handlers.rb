module SlackStatusCli
  module Cli
    module Commands
      # Installs INT/TERM traps plus an at_exit hook so a Ctrl-C (or kill) during
      # a long-running status mode clears the Slack status on the way out. The
      # signal/exit/clear collaborators are injected (defaulting to the real
      # Signal/Kernel/ClearStatus) so the behavior is testable without registering
      # process-global handlers that would fire on the test runner's own exit.
      class InstallSignalHandlers
        extend Callable

        SIGNALS = %w[INT TERM].freeze
        GOODBYE = "\nStopping Slack client… sending goodbye to Music ❤️".freeze

        def initialize(
          token:,
          signals: SIGNALS,
          trapper: ::Signal,
          exit_hook: ::Kernel,
          clearer: Slack::Commands::ClearStatus,
          terminator: -> { ::Kernel.exit },
          output: $stdout
        )
          @token = token
          @signals = signals
          @trapper = trapper
          @exit_hook = exit_hook
          @clearer = clearer
          @terminator = terminator
          @output = output
        end

        def call
          shutdown_requested = false

          signals.each do |signal|
            trapper.trap(signal) do
              shutdown_requested = true
              terminator.call
            end
          end

          exit_hook.at_exit do
            next unless shutdown_requested && token

            output.puts(GOODBYE)
            clearer.call(token: token)
          end

          nil
        end

        private

        attr_reader :token, :signals, :trapper, :exit_hook, :clearer, :terminator, :output
      end
    end
  end
end
