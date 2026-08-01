module SlackStatusCli
  module Slack
    module Commands
      # Sets the Slack user status. Builds the users.profile.set body via
      # Builders::StatusPayload, POSTs it through Http::PostRequest, hands the
      # raw response to Formatters::ResponseLogger, and returns that response so
      # callers can inspect it. `now:` is injectable for deterministic specs.
      class SetStatus
        extend Callable

        PATH = "users.profile.set".freeze

        def initialize(token:, text:, emoji:, expiration:, output: $stdout, now: Time.now)
          @token = token
          @text = text
          @emoji = emoji
          @expiration = expiration
          @output = output
          @now = now
        end

        def call
          output.puts(pre_send_line)
          response = Http::PostRequest.call(token: token, path: PATH, body: payload)
          Formatters::ResponseLogger.call(response: response, output: output)
          response
        end

        private

        attr_reader :token, :text, :emoji, :expiration, :output, :now

        def pre_send_line
          return "📤 Clearing Slack status (empty)" if text.to_s.empty? && emoji.to_s.empty?

          label = [emoji, text].reject { |part| part.to_s.empty? }.join(" ")
          "📤 Setting Slack status: #{label}"
        end

        def payload
          Builders::StatusPayload.call(text: text, emoji: emoji, expiration: expiration, now: now)
        end
      end
    end
  end
end
