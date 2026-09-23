# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::MCP::ResourceTemplate do
  {
    ['file:///{path}', { path: 'docs/README.md' }] => 'file:///docs%2FREADME.md',
    ['file:///{+path}', { path: 'docs/README.md' }] => 'file:///docs/README.md',
    ['repo://{owner}/{repo}', { owner: 'crmne', repo: 'ruby llm' }] => 'repo://crmne/ruby%20llm',
    ['search{?q,limit}', { q: 'mcp', limit: 5 }] => 'search?q=mcp&limit=5',
    ['items{/id}', { id: 42 }] => 'items/42',
    ['file:///{path}', {}] => 'file:///',
    ['{{name}}', { name: 'x' }] => '{x}'
  }.each do |(template, variables), expanded|
    it "expands #{template} with #{variables}" do
      expect(described_class.expand(template, variables)).to eq(expanded)
    end
  end
end
