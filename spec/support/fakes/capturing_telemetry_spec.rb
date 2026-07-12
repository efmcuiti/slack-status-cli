require "spec_helper"

RSpec.describe CapturingTelemetry do
  it "records message, tags, and level for each rich_log call" do
    telemetry = described_class.new

    telemetry.rich_log(message: "did a thing", tags: { name: "rocket" }, level: :warn)

    entry = telemetry.entry_for("did a thing")
    expect(entry.tags).to eq(name: "rocket")
    expect(entry.level).to eq(:warn)
  end

  it "defaults the level to :info and tags to empty" do
    telemetry = described_class.new

    telemetry.rich_log(message: "plain")

    entry = telemetry.entry_for("plain")
    expect(entry.level).to eq(:info)
    expect(entry.tags).to eq({})
  end

  it "snapshots tags so later mutation of the caller's Hash can't alter a recorded entry" do
    telemetry = described_class.new
    tags = { name: "rocket" }

    telemetry.rich_log(message: "did a thing", tags: tags)
    tags[:name] = "mutated"

    expect(telemetry.entry_for("did a thing").tags).to eq(name: "rocket")
  end

  it "exposes the ordered list of messages and returns nil like NullLogger" do
    telemetry = described_class.new

    result = telemetry.rich_log(message: "first")
    telemetry.rich_log(message: "second")

    expect(result).to be_nil
    expect(telemetry.messages).to eq(["first", "second"])
  end
end
