RSpec.describe RubyLLM::Message do
  it "deep converts tool_calls in #to_h" do
    tc  = RubyLLM::ToolCall.new(id: "call_1", name: "weather", arguments: {"city" => "Berlin"})
    msg = described_class.new(role: :assistant, content: "hi", tool_calls: [tc])

    h = msg.to_h
    expect(h[:tool_calls]).to eq([{ id: "call_1", name: "weather", arguments: {"city" => "Berlin"} }])
  end

  it "converts tool_calls hashes to ToolCall objects" do
    hash = { id: "call_2", name: "math", arguments: { x: 1 } }
    msg = described_class.new(role: :assistant, content: "hi", tool_calls: [hash])
    expect(msg.tool_calls.first).to be_a(RubyLLM::ToolCall)
    expect(msg.tool_calls.first.id).to eq("call_2")
    expect(msg.tool_calls.first.name).to eq("math")
    expect(msg.tool_calls.first.arguments).to eq({ x: 1 })
  end

  it "accepts ToolCall objects directly" do
    tc = RubyLLM::ToolCall.new(id: "call_3", name: "sum", arguments: { y: 2 })
    msg = described_class.new(role: :assistant, content: "hi", tool_calls: [tc])
    expect(msg.tool_calls.first).to be_a(RubyLLM::ToolCall)
    expect(msg.tool_calls.first.id).to eq("call_3")
    expect(msg.tool_calls.first.name).to eq("sum")
    expect(msg.tool_calls.first.arguments).to eq({ y: 2 })
  end
end
