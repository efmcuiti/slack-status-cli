require "spec_helper"

RSpec.describe SlackStatusCli::Cli::Errors do
  describe "Error" do
    it "is a subclass of StandardError" do
      expect(described_class::Error.ancestors).to include(StandardError)
    end
  end

  describe "HelpRequested" do
    it "descends from Errors::Error" do
      expect(described_class::HelpRequested.ancestors).to include(described_class::Error)
    end

    it "carries the help text it was raised with" do
      error = described_class::HelpRequested.new("the help text")
      expect(error.help_text).to eq("the help text")
    end
  end
end
