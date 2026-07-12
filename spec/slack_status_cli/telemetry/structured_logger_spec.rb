require "spec_helper"
require "json"
require "stringio"

RSpec.describe SlackStatusCli::Telemetry::StructuredLogger do
  let(:io) { StringIO.new }

  def emitted_lines
    io.string.each_line.to_a
  end

  def emitted_json
    JSON.parse(emitted_lines.first)
  end

  describe "#rich_log" do
    it "emits exactly one JSON line terminated by a newline" do
      described_class.new(io: io).rich_log(message: "status set")

      expect(emitted_lines.length).to eq(1)
      expect(io.string).to end_with("\n")
      expect { emitted_json }.not_to raise_error
    end

    it "carries the constant message" do
      described_class.new(io: io).rich_log(message: "status set")

      expect(emitted_json["message"]).to eq("status set")
    end

    it "tags the line with the component name as caller" do
      described_class.new(io: io).rich_log(message: "status set")

      expect(emitted_json["caller"]).to eq("SlackStatusCli::Telemetry::StructuredLogger")
    end

    it "falls back to the superclass name as caller for an anonymous subclass" do
      Class.new(described_class).new(io: io).rich_log(message: "status set")

      expect(emitted_json["caller"]).to eq("SlackStatusCli::Telemetry::StructuredLogger")
    end

    it "merges log_tags (the override hook) onto every line" do
      tagged = Class.new(described_class) do
        def log_tags = { service: "slack" }
      end

      tagged.new(io: io).rich_log(message: "status set", tags: { attempt: 1 })

      expect(emitted_json).to include("service" => "slack", "attempt" => 1)
    end

    it "lets a per-call tag win over log_tags on a key collision" do
      tagged = Class.new(described_class) do
        def log_tags = { scope: "global" }
      end

      tagged.new(io: io).rich_log(message: "status set", tags: { scope: "call" })

      expect(emitted_json["scope"]).to eq("call")
    end

    it "records the given level" do
      described_class.new(io: io).rich_log(message: "boom", level: :error)

      expect(emitted_json["level"]).to eq("error")
    end

    it "keeps the reserved message field even when a string-keyed tag tries to override it" do
      described_class.new(io: io).rich_log(message: "real", tags: { "message" => "spoofed" })

      expect(emitted_json["message"]).to eq("real")
      expect(io.string.scan(/"message"/).length).to eq(1)
    end

    it "keeps the normalized level even when a string-keyed tag tries to override it" do
      described_class.new(io: io).rich_log(message: "boom", level: :error, tags: { "level" => "debug" })

      expect(emitted_json["level"]).to eq("error")
      expect(io.string.scan(/"level"/).length).to eq(1)
    end

    it "keeps the caller identity even when a tag tries to override it" do
      described_class.new(io: io).rich_log(message: "status set", tags: { caller: "spoofed" })

      expect(emitted_json["caller"]).to eq("SlackStatusCli::Telemetry::StructuredLogger")
    end

    it "keeps the init-time run_id even when a tag tries to override it" do
      described_class.new(io: io, run_id: "abc123").rich_log(message: "status set", tags: { "run_id" => "spoofed" })

      expect(emitted_json["run_id"]).to eq("abc123")
    end

    it "never lets a tag introduce run_id when none was set at init" do
      described_class.new(io: io).rich_log(message: "status set", tags: { "run_id" => "spoofed" })

      expect(emitted_json).not_to have_key("run_id")
    end

    it "falls back to :info when the level is invalid" do
      described_class.new(io: io).rich_log(message: "hmm", level: :loud)

      expect(emitted_json["level"]).to eq("info")
    end

    it "falls back to :info when the level is nil" do
      described_class.new(io: io).rich_log(message: "hmm", level: nil)

      expect(emitted_json["level"]).to eq("info")
    end

    it "falls back to :info for a non-symbolizable level rather than raising" do
      logger = described_class.new(io: io)

      expect { logger.rich_log(message: "hmm", level: 5) }.not_to raise_error
      expect(emitted_json["level"]).to eq("info")
    end

    it "writes to the injected io" do
      described_class.new(io: io).rich_log(message: "status set")

      expect(io.string).not_to be_empty
    end

    it "defaults the sink to $stderr, leaving $stdout clean for human output" do
      captured = capture_stdio { described_class.new.rich_log(message: "status set") }

      expect(captured[:stderr]).to include("status set")
      expect(captured[:stdout]).to be_empty
    end

    it "carries run_id on every line when one is supplied" do
      described_class.new(io: io, run_id: "abc123").rich_log(message: "status set")

      expect(emitted_json["run_id"]).to eq("abc123")
    end

    it "omits run_id entirely when none is supplied" do
      described_class.new(io: io).rich_log(message: "status set")

      expect(emitted_json).not_to have_key("run_id")
    end

    context "secret scrubbing" do
      it "redacts a Slack token appearing in the message" do
        described_class.new(io: io).rich_log(message: "auth failed with xoxp-abcd1234efgh")

        expect(emitted_json["message"]).not_to include("xoxp-abcd1234efgh")
        expect(emitted_json["message"]).to include("xox?-…efgh")
      end

      it "redacts a Slack token appearing in a tag value" do
        described_class.new(io: io).rich_log(message: "boom", tags: { token: "xoxb-zzzzyyyy1111" })

        expect(emitted_json["token"]).not_to include("xoxb-zzzzyyyy1111")
        expect(emitted_json["token"]).to include("xox?-…1111")
      end

      it "leaves non-string tag values untouched (no stringifying scalars)" do
        described_class.new(io: io).rich_log(message: "boom", tags: { attempt: 3 })

        expect(emitted_json["attempt"]).to eq(3)
      end

      it "redacts a token nested inside a hash tag value" do
        described_class.new(io: io).rich_log(message: "boom", tags: { payload: { token: "xoxb-zzzzyyyy1111" } })

        expect(io.string).not_to include("xoxb-zzzzyyyy1111")
        expect(emitted_json.dig("payload", "token")).to include("xox?-…1111")
      end

      it "redacts a token nested inside an array tag value" do
        described_class.new(io: io).rich_log(message: "boom", tags: { items: ["safe", "xoxp-abcd1234efgh"] })

        expect(io.string).not_to include("xoxp-abcd1234efgh")
        expect(emitted_json["items"]).to include(a_string_including("xox?-…efgh"))
        expect(emitted_json["items"]).to include("safe")
      end

      it "still emits a single valid JSON object after scrubbing" do
        described_class.new(io: io).rich_log(message: "leaked xoxp-abcd1234efgh", tags: { token: "xoxb-zzzzyyyy1111" })

        expect(emitted_lines.length).to eq(1)
        expect { emitted_json }.not_to raise_error
        expect(io.string).not_to include("xoxp-abcd1234efgh")
        expect(io.string).not_to include("xoxb-zzzzyyyy1111")
      end
    end
  end
end
