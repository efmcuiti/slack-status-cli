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

          server.mount_proc("/callback") do |req, res|
            outcome = Queries::HandleCallbackRequest.call(params: req.query, expected_state: expected_state)
            res.status = outcome[:status]
            res.body = outcome[:body]
            Thread.new { sleep 0.2; server.shutdown }
          end

          timed_out = false
          timer = Thread.new do
            sleep timeout
            timed_out = true
            server.shutdown
          end

          trap("INT") { server.shutdown }
          server.start
          timer.kill if timer.alive?

          raise Errors::Timeout, "OAuth callback timed out after #{timeout}s" if timed_out || outcome.nil?

          case outcome[:error]
          when nil
            { code: outcome[:code], state: outcome[:state] }
          when "state_mismatch"
            raise Errors::StateMismatch, "OAuth state mismatch (CSRF guard)"
          else
            raise Errors::Error, "OAuth callback failed (#{outcome[:error]})"
          end
        end

        private

        attr_reader :port, :timeout, :expected_state

        def build_server
          WEBrick::HTTPServer.new(
            Port: port,
            BindAddress: "127.0.0.1",
            ReuseAddr: true,
            Logger: WEBrick::Log.new(File::NULL),
            AccessLog: []
          )
        rescue Errno::EADDRINUSE
          raise Errors::PortBusy, <<~MSG.strip
            Port #{port} is already in use on 127.0.0.1.
            Most likely a previous `setup` run is still alive. Find it and kill it:
              lsof -nP -iTCP:#{port} -sTCP:LISTEN -t | xargs -r kill
            Then re-run: ruby slack_status.rb setup --profile <name> --rotate
          MSG
        end
      end
    end
  end
end
