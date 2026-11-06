# frozen_string_literal: true

require 'erb'
require 'json'

# Recalculates the totals and the chart the provider coverage page shows.
module ProviderCoverageTasks
  DATA = 'docs/_data/provider_coverage.json'
  CHART = 'docs/assets/images/provider-coverage.svg'
  TEMPLATE = 'tasks/templates/provider_coverage_chart.svg.erb'

  module_function

  def summary(data)
    shared = data['groups'].select { |group| group['summary'] }
    groups = shared.map { |group| group_summary(group, group_cells(data, group['id'])) }
    feature_count = shared.sum { |group| data['features'].count { |feature| feature['group'] == group['id'] } }

    { 'feature_count' => feature_count, 'groups' => groups, 'maximum' => groups.map { |group| group['offered'] }.max }
  end

  def group_cells(data, group_id)
    ids = data['features'].select { |feature| feature['group'] == group_id }.map { |feature| feature['id'] }

    data['providers'].flat_map { |provider| provider['features'].values_at(*ids) }
  end

  def group_summary(group, cells)
    { 'id' => group['id'], 'name' => group['name'],
      'v1' => cells.count { |cell| cell['v1'] == 'native' },
      'v2' => cells.count { |cell| cell['v2'] == 'native' },
      'offered' => cells.count { |cell| cell['offered'] == true && cell['v2'] != 'out_of_scope' } }
  end

  def write_summary(source, totals)
    line = JSON.generate(totals, space: ' ').gsub(',"', ', "').gsub(',{', ', {')
    source.sub(/^  "summary": .*$/) { %(  "summary": #{line},) }
  end

  def chart(data, totals)
    ERB.new(File.read(TEMPLATE), trim_mode: '-').result_with_hash(data:, totals:)
  end
end

namespace :docs do
  desc 'Recalculate the provider coverage totals and redraw the chart'
  task :coverage do
    source = File.read(ProviderCoverageTasks::DATA)
    data = JSON.parse(source)
    totals = ProviderCoverageTasks.summary(data)

    File.write(ProviderCoverageTasks::DATA, ProviderCoverageTasks.write_summary(source, totals))
    File.write(ProviderCoverageTasks::CHART, ProviderCoverageTasks.chart(data, totals))
  end
end
