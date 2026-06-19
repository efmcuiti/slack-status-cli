require "spec_helper"

RSpec.describe SlackStatusCli::Oauth::Views::ErrorPage do
  describe ".call" do
    it "renders the given reason in the page" do
      expect(described_class.call(reason: "OAuth state mismatch (CSRF guard)"))
        .to include("OAuth state mismatch (CSRF guard)")
    end

    it "HTML-escapes the reason so it cannot inject markup" do
      html = described_class.call(reason: "<script>alert(1)</script>")

      expect(html).to include("&lt;script&gt;")
      expect(html).not_to include("<script>alert(1)</script>")
    end

    it "returns a complete HTML document" do
      html = described_class.call(reason: "boom")
      expect(html).to include("<html").and include("</html>")
    end
  end
end
