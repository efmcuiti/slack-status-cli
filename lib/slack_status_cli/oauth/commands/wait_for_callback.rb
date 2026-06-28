require "webrick"

module SlackStatusCli
  module Oauth
    module Commands
      # Untested orchestrator glue. Boots a one-shot WEBrick listener bound to
      # loopback only, delegates every /callback request to the pure
      # Queries::HandleCallbackRequest, serves the payload it returns, then shuts
      # down. Returns { code:, state: } on success and raises the matching
      # Errors::* on a timeout, a state mismatch, or any other failure outcome.
      #
      # `ReuseAddr: true` so a killed-then-restarted setup doesn't have to wait
      # out the kernel's TIME_WAIT window on the socket.
      class WaitForCallback
        extend Callable

        def initialize(port:, timeout:, expected_state:)
          @port = port
          @timeout = timeout
          @expected_state = expected_state
        end

        def call
          server = build_server
          outcome = nil
          cancelled = false

          server.mount_proc("/callback") do |req, res|
            outcome = Queries::HandleCallbackRequest.call(params: req.query, expected_state: expected_state)
            res.status = outcome[:status]
            res.body = outcome[:body]
            Thread.new { sleep 0.2; server.shutdown }
          end

          timer = Thread.new do
            sleep timeout
            server.shutdown
          end

          # Capture the prior INT handler so we can restore it: this is a
          # one-shot server and the surrounding `setup` flow continues after we
          # return, so leaving our handler installed would break Ctrl+C later.
          previous_int = trap("INT") do
            cancelled = true
            server.shutdown
          end

          begin
            server.start
          rescue Errors::Error
            raise
          rescue StandardError => e
            raise Errors::Error, "OAuth listener failed: #{e.message}"
          ensure
            timer.kill if timer.alive?
            restore_int(previous_int)
          end

          raise Errors::Error, "OAuth flow cancelled (Ctrl+C)" if cancelled
          # `outcome` is the authoritative signal a callback was handled, so a
          # callback landing right at the timeout boundary is never lost to the
          # timer thread's shutdown.
          raise Errors::Timeout, "OAuth callback timed out after #{timeout}s" if outcome.nil?

          case outcome[:error]
          when nil
            { code: outcome[:code], state: outcome[:state] }
          when "state_mismatch"
            raise Errors::StateMismatch, "OAuth state mismatch (CSRF guard)"
          when "missing_code"
            raise Errors::Error, "OAuth callback missing `code`"
          else
            raise Errors::Error, "Slack returned error=#{outcome[:error]}"
          end
        end

        private

        attr_reader :port, :timeout, :expected_state

        def restore_int(previous)
          if previous.respond_to?(:call)
            trap("INT", &previous)
          else
            trap("INT", previous || "DEFAULT")
          end
        end

        def build_server
          WEBrick::HTTPServer.new(
            Port: port,
            # Bind to "localhost" (both 127.0.0.1 and ::1), not literal
            # 127.0.0.1: the redirect URI is http://localhost/callback, and on
            # IPv6-first systems the browser may hit ::1. Still loopback-only,
            # so off-host callers can't race the callback.
            BindAddress: "localhost",
            ReuseAddr: true,
            Logger: WEBrick::Log.new(File::NULL),
            AccessLog: []
          )
        rescue Errno::EADDRINUSE
          raise Errors::PortBusy, <<~MSG.strip
            Port #{port} is already in use on localhost.
            Most likely a previous `setup` run is still alive. Find it and kill it:
              kill $(lsof -nP -iTCP:#{port} -sTCP:LISTEN -t)
            Then re-run: ruby slack_status.rb setup --profile <name> --rotate
          MSG
        end
      end
    end
  end
end
