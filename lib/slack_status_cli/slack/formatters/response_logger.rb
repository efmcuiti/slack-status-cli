require "json"

module SlackStatusCli
  module Slack
    module Formatters
      # Logs the outcome of a Slack API call to `output:` (defaults to
      # `$stdout`). Mirrors the success/empty/non-JSON/non-2xx branches of
      # the original `Slack#handle_response`, and defers token scrubbing to
      # `SlackStatusCli::SecretScrubber` so xox*-tokens never leak into the
      # log.
      class ResponseLogger
        extend Callable

        SUCCESS_RANGE = (200..299)
        BODY_EXCERPT_LIMIT = 200

        def initialize(response:, output: $stdout)
          @response = response
          @output = output
        end

        def call
          success? ? log_success : log_failure
          nil
        end

        private

        attr_reader :response, :output

        def success?
          SUCCESS_RANGE.cover?(response.code.to_i)
        end

        def log_success
          body = response.body.to_s

          if body.strip.empty?
            output.puts "⚠️  Empty response from Slack (HTTP #{response.code}); skipping this tick."
            return
          end

          parsed = parse_json(body)
          return if parsed.nil?

          if parsed["ok"]
            output.puts "✅ Slack status updated!"
          else
            output.puts "❌ Failed to update status: #{SlackStatusCli::SecretScrubber.call(text: parsed["error"])}"
          end
        end

        def log_failure
          body = response.body.to_s
          tail = body.strip.empty? ? "" : " — #{body_excerpt(body)}"
          output.puts "❌ Slack HTTP #{response.code} #{response.message}#{tail}"
        end

        def parse_json(body)
          JSON.parse(body)
        rescue JSON::ParserError => e
          output.puts "⚠️  Non-JSON response from Slack: #{e.message} — #{body_excerpt(body)}"
          nil
        end

        def body_excerpt(body)
          snippet = SlackStatusCli::SecretScrubber.call(text: body.strip)
          snippet.length > BODY_EXCERPT_LIMIT ? "#{snippet[0, BODY_EXCERPT_LIMIT]}…" : snippet
        end
      end
    end
  end
end
