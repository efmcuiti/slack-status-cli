require "spec_helper"

RSpec.describe SlackStatusCli::Callable do
  let(:service) do
    Class.new do
      extend SlackStatusCli::Callable

      def initialize(value:)
        @value = value
      end

      def call
        block_given? ? yield(@value) : @value
      end
    end
  end

  describe ".call" do
    it "forwards keyword arguments to the initializer" do
      expect(service.call(value: 42)).to eq(42)
    end

    it "forwards a block through to the instance #call so it can yield" do
      seen = nil
      service.call(value: 7) { |value| seen = value }

      expect(seen).to eq(7)
    end

    it "still works when no block is given" do
      expect(service.call(value: "plain")).to eq("plain")
    end
  end
end
