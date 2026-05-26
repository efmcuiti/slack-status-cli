require "spec_helper"
require "json"
require "stringio"

RSpec.describe SlackStatusCli::Slack::Formatters::ResponseLogger do
  let(:output) { StringIO.new }

  def fake_response(code:, message: "OK", body: "")
    Struct.new(:code, :message, :body).new(code.to_s, message, body)
  end

  describe ".call" do
    context "with a 2xx response" do
      it "logs a success line when Slack returns ok=true" do
        response = fake_response(code: 200, body: { ok: true }.to_json)

        described_class.call(response: response, output: output)

        expect(output.string).to eq("✅ Slack status updated!\n")
      end

      it "logs a Slack-side API error when ok=false" do
        response = fake_response(code: 200, body: { ok: false, error: "invalid_auth" }.to_json)

        described_class.call(response: response, output: output)

        expect(output.string).to include("❌ Failed to update status: invalid_auth")
      end

      it "warns when the body is empty so a tick can be safely skipped" do
        response = fake_response(code: 200, body: "")

        described_class.call(response: response, output: output)

        expect(output.string).to include("⚠️  Empty response from Slack (HTTP 200)")
      end

      it "warns when the body is non-JSON and includes the parser message" do
        response = fake_response(code: 200, body: "not json at all")

        described_class.call(response: response, output: output)

        expect(output.string).to include("⚠️  Non-JSON response from Slack")
        expect(output.string).to include("not json at all")
      end
    end

    context "with a non-2xx response" do
      it "logs an HTTP error line including code, message, and a body excerpt" do
        response = fake_response(code: 401, message: "Unauthorized", body: "invalid_auth")

        described_class.call(response: response, output: output)

        expect(output.string).to include("❌ Slack HTTP 401 Unauthorized")
        expect(output.string).to include("invalid_auth")
      end

      it "omits the body excerpt when the failure body is blank" do
        response = fake_response(code: 500, message: "Internal Server Error", body: "")

        described_class.call(response: response, output: output)

        expect(output.string).to eq("❌ Slack HTTP 500 Internal Server Error\n")
      end

      it "scrubs Slack tokens from the logged body via SecretScrubber" do
        body = '{"error":"invalid_auth","token":"xoxp-abcd1234efgh"}'
        response = fake_response(code: 401, message: "Unauthorized", body: body)

        described_class.call(response: response, output: output)

        expect(output.string).not_to include("xoxp-abcd1234efgh")
        expect(output.string).to include("xox?-…efgh")
      end

      it "delegates body scrubbing to SecretScrubber so the policy stays in one place" do
        body = "boom xoxb-zzzzyyyy1111"
        response = fake_response(code: 502, message: "Bad Gateway", body: body)
        expect(SlackStatusCli::SecretScrubber).to receive(:call).with(text: body.strip).and_call_original

        described_class.call(response: response, output: output)
      end

      it "truncates very long body excerpts with an ellipsis" do
        body = "x" * 300
        response = fake_response(code: 500, message: "Internal Server Error", body: body)

        described_class.call(response: response, output: output)

        expect(output.string).to include("#{'x' * 200}…")
      end
    end

    it "returns nil so callers know the logger only writes to output" do
      response = fake_response(code: 200, body: { ok: true }.to_json)

      result = described_class.call(response: response, output: output)

      expect(result).to be_nil
    end

    it "defaults output: to $stdout when no IO is supplied" do
      response = fake_response(code: 200, body: { ok: true }.to_json)

      captured = capture_stdio { described_class.call(response: response) }

      expect(captured[:stdout]).to include("✅ Slack status updated!")
    end
  end
end
