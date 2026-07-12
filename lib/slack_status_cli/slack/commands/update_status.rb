module SlackStatusCli
  module Slack
    module Commands
      # Top-level status dispatcher. Branches on `mode`:
      #   - :clear         -> ClearStatus
      #   - :musical_myth  -> RunMusicalLoop (blocks until interrupted)
      #   - known mode     -> SetStatus with the ModeStatus triple, with any
      #                       explicit text/emoji/expiration taking precedence
      #   - unknown mode   -> custom freeform SetStatus built from the explicit
      #                       text/emoji/expiration args (the documented
      #                       `custom` status; empty args yield an empty status)
      class UpdateStatus
        extend Callable

        def initialize(token:, mode:, text: nil, emoji: nil, expiration: nil, output: $stdout, telemetry: Telemetry::NullLogger.new)
          @token = token
          @mode = mode
          @text = text
          @emoji = emoji
          @expiration = expiration
          @output = output
          @telemetry = telemetry
        end

        def call
          case mode
          when :clear
            ClearStatus.call(token: token, output: output)
          when :musical_myth
            RunMusicalLoop.call(token: token, output: output, telemetry: telemetry)
          else
            set_mode_status
          end
        end

        private

        attr_reader :token, :mode, :text, :emoji, :expiration, :output, :telemetry

        def set_mode_status
          status = mode_defaults
          SetStatus.call(
            token: token,
            text: text || status[:text],
            emoji: emoji || status[:emoji],
            expiration: expiration || status[:expiration],
            output: output
          )
        end

        # Known modes carry their own text/emoji/expiration defaults. An
        # unrecognized mode (the documented `custom` status) has no defaults —
        # it is built entirely from the explicit args, falling back to an empty
        # status when none are given.
        def mode_defaults
          Builders::ModeStatus.call(mode: mode)
        rescue ArgumentError
          { text: "", emoji: "", expiration: nil }
        end
      end
    end
  end
end
