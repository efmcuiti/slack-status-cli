require "spec_helper"

RSpec.describe SlackStatusCli::EmojiMigration::Errors do
  describe "Error" do
    it "is a subclass of StandardError" do
      expect(described_class::Error.ancestors).to include(StandardError)
    end
  end

  describe "MissingScope" do
    it "descends from Errors::Error" do
      expect(described_class::MissingScope.ancestors).to include(described_class::Error)
    end
  end
end
