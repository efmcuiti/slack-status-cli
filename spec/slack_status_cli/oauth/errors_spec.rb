require "spec_helper"

RSpec.describe SlackStatusCli::Oauth::Errors do
  describe "Error" do
    it "is a subclass of StandardError" do
      expect(described_class::Error.ancestors).to include(StandardError)
    end
  end

  describe "the specialized errors" do
    it "all descend from Errors::Error" do
      [
        described_class::StateMismatch,
        described_class::Timeout,
        described_class::ExchangeFailed,
        described_class::PortBusy
      ].each do |klass|
        expect(klass.ancestors).to include(described_class::Error)
      end
    end
  end
end
