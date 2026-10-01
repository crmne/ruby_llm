# frozen_string_literal: true

require 'json'

module Benchmarks
  # The values one metric of one case took across runs.
  class Series
    attr_reader :name, :metric, :unit, :values

    def self.from_h(hash)
      new(hash.fetch('name'), hash.fetch('metric'), hash.fetch('unit'), hash.fetch('values'))
    end

    def initialize(name, metric, unit, values)
      @name = name
      @metric = metric.to_s
      @unit = unit.to_s
      @values = values
    end

    def median
      sorted = values.sort
      middle = sorted.size / 2
      sorted.size.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2.0
    end

    def min = values.min
    def max = values.max

    def key = [name, metric]

    def to_h = { name:, metric:, unit:, values: }

    def summary
      text = Report.format_value(median, unit)
      low = Report.format_number(min)
      high = Report.format_number(max)
      low == high ? text : "#{text} (#{low}-#{high})"
    end
  end

  # Prints the results of one area, and the comparison of two runs of it.
  class Report
    attr_reader :area, :target, :series

    def self.load(path)
      data = JSON.parse(File.read(path))
      new(data.fetch('area'), data.fetch('target'), data.fetch('series').map { |hash| Series.from_h(hash) })
    end

    # Combines the runs of several reports of one area and target.
    def self.merge(reports)
      series = reports.flat_map(&:series).group_by(&:key).map do |_key, group|
        Series.new(group.first.name, group.first.metric, group.first.unit, group.flat_map(&:values))
      end
      new(reports.first.area, reports.first.target, series)
    end

    def self.format_number(value)
      return format('%.2fM', value / 1_000_000.0) if value.abs >= 1_000_000
      return format('%.1fk', value / 1000.0) if value.abs >= 10_000
      return value.round.to_s if value.abs >= 100 || value == value.round
      return format('%.1f', value) if value.abs >= 10
      return format('%.2f', value) if value.abs >= 1

      format('%.3f', value)
    end

    def self.format_value(value, unit)
      [format_number(value), unit].reject(&:empty?).join(' ')
    end

    # Counts read best as both values, times as a speedup once they halve,
    # and the rest as a percentage.
    def self.change(before, after)
      was = before.median
      now = after.median
      return 'same' if was == now
      return "#{format_number(was)} -> #{format_number(now)}" if was.zero? || now.zero? || before.unit.empty?

      ratio(now.fdiv(was), time: before.unit == 'ms')
    end

    def self.ratio(ratio, time:)
      return format("%.1fx #{time ? 'faster' : 'less'}", 1 / ratio) if ratio <= 0.5
      return format("%.1fx #{time ? 'slower' : 'more'}", ratio) if ratio >= 2

      format('%+.0f%%', (ratio - 1) * 100)
    end

    def self.table(rows)
      widths = rows.transpose.map { |column| column.map(&:length).max }
      rows.map { |row| row.zip(widths).map { |cell, width| cell.ljust(width) }.join('  ').rstrip }
    end

    def self.compare(before, after)
      after_series = after.series.to_h { |series| [series.key, series] }
      rows = before.series.filter_map do |series|
        other = after_series[series.key]
        [series.name, series.metric, series.summary, other.summary, change(series, other)] if other
      end
      header = ['Case', 'Metric', before.target, after.target, 'Change']
      ["\n#{before.area}", *table([header, *rows])].join("\n")
    end

    def initialize(area, target, series = [])
      @area = area
      @target = target
      @series = series
    end

    def add(name, metric, unit, values)
      Series.new(name, metric, unit, values).tap { |series| @series << series }
    end

    def to_s
      rows = series.map { |item| [item.name, item.metric, item.summary, item.values.size.to_s] }
      ["\n#{area}: #{target}", *self.class.table([%w[Case Metric Median Runs], *rows])].join("\n")
    end

    def write(path)
      File.write(path, JSON.pretty_generate(area:, target:, series: series.map(&:to_h)))
    end
  end
end
