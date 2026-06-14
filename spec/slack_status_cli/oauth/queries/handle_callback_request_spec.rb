require "spec_helper"

RSpec.describe SlackStatusCli::Oauth::Queries::HandleCallbackRequest do
  describe ".call" do
    let(:state) { "expected-state-123" }

    context "with a valid code + matching state" do
      let(:result) do
        described_class.call(
          params: build_callback_params(code: "auth-code-1", state: state),
          expected_state: state
        )
      end

      it "returns the code, matching state, and no error" do
        expect(result).to include(code: "auth-code-1", state: state, error: nil)
      end

      it "serves HTTP 200" do
        expect(result[:status]).to eq(200)
      end

      it "serves the success body" do
        expect(result[:body]).to include("Slack token received")
      end
    end

    context "with a state mismatch" do
      let(:result) do
        described_class.call(
          params: build_callback_params(code: "auth-code-1", state: "attacker-state"),
          expected_state: state
        )
      end

      it "returns a state_mismatch error with HTTP 400" do
        expect(result).to include(error: "state_mismatch", status: 400)
      end

      it "withholds the code" do
        expect(result[:code]).to be_nil
      end

      it "serves the error body" do
        expect(result[:body]).to include("OAuth failed")
      end
    end

    context "with an error param from Slack" do
      let(:result) do
        described_class.call(
          params: build_callback_params(error: "access_denied", code: nil, state: state),
          expected_state: state
        )
      end

      it "passes the Slack error through with HTTP 400" do
        expect(result).to include(error: "access_denied", status: 400)
      end

      it "serves the error body" do
        expect(result[:body]).to include("OAuth failed")
      end
    end

    context "with missing code" do
      let(:result) do
        described_class.call(
          params: build_callback_params(code: nil, state: state),
          expected_state: state
        )
      end

      it "returns a missing_code error with HTTP 400" do
        expect(result).to include(error: "missing_code", status: 400)
      end

      it "serves the error body" do
        expect(result[:body]).to include("OAuth failed")
      end
    end
  end
end
