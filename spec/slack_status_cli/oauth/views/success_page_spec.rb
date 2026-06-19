require "spec_helper"

RSpec.describe SlackStatusCli::Oauth::Views::SuccessPage do
  describe ".call" do
    it "tells the user the token was received" do
      expect(described_class.call).to include("Slack token received")
    end

    it "returns a complete HTML document" do
      html = described_class.call
      expect(html).to include("<html").and include("</html>")
    end
  end
end
