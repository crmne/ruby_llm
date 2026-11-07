# frozen_string_literal: true

require 'rails_helper'
require 'ruby_llm/active_record/chat_helper'

RSpec.describe RubyLLM::ActiveRecord::ChatHelper do
  include_context 'with configured RubyLLM'

  let(:views) { Dir.mktmpdir('ruby_llm_chat_helper_views') }

  after { FileUtils.remove_entry(views) }

  def write(path, source)
    file = File.join(views, path)
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, source)
  end

  def view
    ActionView::Base.with_empty_template_cache.with_view_paths([views])
  end

  def tool_call(name) = RubyLLM::ToolCall.new(id: 'call_1', name:, arguments: {})

  def tool_result(name)
    Struct.new(:parent_tool_call).new(name && tool_call(name))
  end

  it 'is available in every view' do
    expect(ActionView::Base.ancestors).to include(described_class)
  end

  it "renders a tool's own partial from the folder beside the template, or that folder's default" do
    write('messages/_tool_calls.html.erb', '<%= render tool_call_partial(tool_call) %>')
    write('messages/tool_calls/_weather.html.erb', 'Weather card')
    write('messages/tool_calls/_default.html.erb', 'Default card')

    rendered = %w[weather search-docs].map do |name|
      view.render(partial: 'messages/tool_calls', locals: { tool_call: tool_call(name) }).strip
    end

    expect(rendered).to eq(['Weather card', 'Default card'])
  end

  it 'finds the partials of namespaced messages in their own folder' do
    write('llm/messages/_tool.html.erb', '<%= render tool_result_partial(tool) %>')
    write('llm/messages/tool_results/_search_docs.html.erb', 'Search result card')
    write('llm/messages/tool_results/_default.html.erb', 'Default result card')

    rendered = ['search-docs', nil].map do |name|
      view.render(partial: 'llm/messages/tool', locals: { tool: tool_result(name) }).strip
    end

    expect(rendered).to eq(['Search result card', 'Default result card'])
  end

  it 'labels tools and costs for a person to read' do
    cost = RubyLLM::Cost.from_h({ 'total' => 0.0123 })

    expect(view.tool_label('send_mail')).to eq('Send mail')
    expect(view.tool_label(nil)).to eq('Tool')
    expect(view.tool_result_label(tool_result('send_mail'))).to eq('Send mail')
    expect(view.cost_label(cost)).to eq('$0.0123')
    expect(view.default_model_display_name)
      .to eq("Default: #{RubyLLM.models.find(RubyLLM.config.default_model).label}")
  end

  it 'gives way to an app helper with the same name' do
    app_helper = Module.new { def cost_label(_cost) = 'priceless' }
    view_class = Class.new(ActionView::Base.with_empty_template_cache) { include app_helper }

    expect(view_class.with_view_paths([views]).cost_label(nil)).to eq('priceless')
  end
end
