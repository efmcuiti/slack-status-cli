module SlackStatusCli
  module Slack
    module Commands
      # Top-level status dispatcher. Branches on `mode`:
      #   - :clear         -> ClearStatus
      #   - :musical_myth  -> RunMusicalLoop (blocks until interrupted)
      #   - known mode     -> SetStatus with the ModeStatus triple, with any
      #                       explicit text/emoji/expiration taking precedence
      #   - unknown mode   -> ClearStatus (an unrecognized mode resolves to the
      #                       same result as :clear)
      class UpdateStatus
        extend Callable

        def initialize(token:, mode:, text: nil, emoji: nil, expiration: nil, output: $stdout)
          @token = token
          @mode = mode
          @text = text
          @emoji = emoji
          @expiration = expiration
          @output = output
        end

        def call
          case mode
          when :clear
            ClearStatus.call(token: token, output: output)
          when :musical_myth
            RunMusicalLoop.call(token: token, output: output)
          else
            set_mode_status
          end
        end

        private

        attr_reader :token, :mode, :text, :emoji, :expiration, :output

        def set_mode_status
          status = Builders::ModeStatus.call(mode: mode)
          SetStatus.call(
            token: token,
            text: text || status[:text],
            emoji: emoji || status[:emoji],
            expiration: expiration || status[:expiration],
            output: output
          )
        rescue ArgumentError
          ClearStatus.call(token: token, output: output)
        end
      end
    end
  end
end
