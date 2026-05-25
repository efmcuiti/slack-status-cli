require "spec_helper"

RSpec.describe FakeSleeper do
  describe "#call" do
    it "records the requested seconds into #calls" do
      sleeper = described_class.new

      sleeper.call(10)
      sleeper.call(0.25)

      expect(sleeper.calls).to eq([10, 0.25])
    end

    it "returns nil to mimic Kernel#sleep's contract" do
      sleeper = described_class.new

      expect(sleeper.call(5)).to be_nil
    end

    context "with raise_after: 3" do
      subject(:sleeper) { described_class.new(raise_after: 3) }

      it "does not raise on calls 1 and 2" do
        expect { sleeper.call(1) }.not_to raise_error
        expect { sleeper.call(1) }.not_to raise_error
      end

      it "raises StopIteration on the 3rd call" do
        sleeper.call(1)
        sleeper.call(1)

        expect { sleeper.call(1) }.to raise_error(StopIteration)
      end

      it "still records the call that raised so specs can assert the loop body ran" do
        sleeper.call(1)
        sleeper.call(2)
        begin
          sleeper.call(3)
        rescue StopIteration
          # expected — test the side effect, not the exception
        end

        expect(sleeper.calls).to eq([1, 2, 3])
      end
    end
  end
end
