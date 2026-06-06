require "spec_helper"

RSpec.describe SlackStatusCli::Slack::Builders::ExpirationSeconds do
  describe ".call" do
    let(:now) { Time.at(1_700_000_000) }

    context "with a plain integer string" do
      it "treats it as relative seconds-from-now and returns now + the value" do
        expect(described_class.call(value: "3600", now: now)).to eq(now.to_i + 3600)
      end
    end

    context "with an integer value" do
      it "treats it as relative seconds-from-now and returns now + the value" do
        expect(described_class.call(value: 3600, now: now)).to eq(now.to_i + 3600)
      end
    end

    context "with a '30m' relative duration" do
      it "returns now + 30 * 60" do
        expect(described_class.call(value: "30m", now: now)).to eq(now.to_i + (30 * 60))
      end
    end

    context "with a '2h' relative duration" do
      it "returns now + 2 * 60 * 60" do
        expect(described_class.call(value: "2h", now: now)).to eq(now.to_i + (2 * 60 * 60))
      end
    end

    context "with nil" do
      it "returns nil" do
        expect(described_class.call(value: nil, now: now)).to be_nil
      end
    end

    context "with a blank string" do
      it "returns nil" do
        expect(described_class.call(value: "   ", now: now)).to be_nil
      end
    end

    context "with garbage" do
      it "returns nil (matches the old #evaluate_expiration behavior)" do
        expect(described_class.call(value: "not-a-duration", now: now)).to be_nil
      end
    end

    it "defaults now: to Time.now for relative durations" do
      result = described_class.call(value: "1m")

      expect(result).to be_within(2).of(Time.now.to_i + 60)
    end
  end
end
