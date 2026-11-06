# frozen_string_literal: true

require 'spec_helper'
require 'json'

RSpec.describe 'Provider coverage data', type: :task do
  let(:root) { File.expand_path('../..', __dir__) }
  let(:data) { JSON.parse(File.read(File.join(root, 'docs/_data/provider_coverage.json'))) }
  let(:cells) { data['providers'].flat_map { |provider| provider['features'].values } }
  let(:shared_groups) { data['groups'].select { |group| group['summary'] }.map { |group| group['id'] } }

  def group_cells(group_id)
    ids = data['features'].select { |feature| feature['group'] == group_id }.map { |feature| feature['id'] }
    data['providers'].flat_map { |provider| provider['features'].values_at(*ids) }
  end

  it 'covers every registered provider' do
    registered = File.read(File.join(root, 'lib/ruby_llm.rb')).scan(/^RubyLLM::Provider\.register :(\w+)/).flatten

    expect(data['providers'].map { |provider| provider['id'] }).to match_array(registered)
  end

  it 'gives every provider a cell for every feature' do
    ids = data['features'].map { |feature| feature['id'] }

    data['providers'].each do |provider|
      expect(provider['features'].keys).to match_array(ids), "#{provider['id']} has different rows"
    end
  end

  it 'totals the summary from the cells' do
    shared_groups.zip(data['summary']['groups']).each do |group_id, summary|
      group = group_cells(group_id)

      expect(summary).to include(
        'id' => group_id,
        'v1' => group.count { |cell| cell['v1'] == 'native' },
        'v2' => group.count { |cell| cell['v2'] == 'native' },
        'offered' => group.count { |cell| cell['offered'] == true && cell['v2'] != 'out_of_scope' }
      ), 'Run rake docs:coverage to recalculate the summary'
    end
  end

  it 'draws the chart from the summary' do
    chart = File.read(File.join(root, 'docs/assets/images/provider-coverage.svg'))

    expect(chart).to include("across #{data['providers'].size} providers on #{data['audited_on']}")
    data['summary']['groups'].each do |group|
      expect(chart).to match(/>#{group['v2']}<.*>#{group['offered']}</m)
    end
  end

  it 'pairs each status with what the provider offers' do
    allowed = { 'na' => [false], 'unknown' => [nil, true] }

    cells.each do |cell|
      expect(allowed.fetch(cell['v2'], [true])).to include(cell['offered']), "#{cell['v2']}: #{cell['notes']}"
    end
  end

  it 'resolves every cited source' do
    cited = cells.flat_map { |cell| cell['sources'] } +
            data['providers'].flat_map { |provider| provider['gaps'].flat_map { |gap| gap['sources'] } }

    expect(cited.uniq - data['sources'].keys).to be_empty
  end

  it 'points its evidence at files that exist' do
    evidence = cells.flat_map do |cell|
      cell['code'].select { |entry| entry['version'] == 'v2' }.map { |entry| entry['path'] } +
        cell.fetch('verification', []).flat_map { |entry| entry.values_at('spec', 'cassette').compact }
    end

    expect(evidence.uniq.reject { |path| File.exist?(File.join(root, path)) }).to be_empty
  end
end
