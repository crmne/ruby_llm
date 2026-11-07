# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require_relative '../../tasks/support/public_api'

RSpec.describe PublicApi do
  def lines_for(source, rdoc_options: "--- {}\n")
    Dir.mktmpdir('public-api') do |root|
      FileUtils.mkdir_p(File.join(root, 'lib', 'internal'))
      File.write(File.join(root, '.rdoc_options'), rdoc_options)
      File.write(File.join(root, 'lib', 'widget.rb'), source)
      File.write(File.join(root, 'lib', 'internal', 'gear.rb'), "# A gear.\nclass Gear\n  def turn; end\nend\n")
      described_class.lines(root)
    end
  end

  let(:source) do
    <<~RUBY
      # A widget.
      class Widget < Base
        include Comparable

        # The size.
        SIZE = 3
        HIDDEN = 4 # :nodoc:

        # The name.
        attr_reader :name

        # Builds one.
        def self.build(name, size: SIZE, &) = new

        # :call-seq:
        #   color(value) -> self
        #   color -> value
        def color(value = nil) = value

        # Spins it.
        def spin = nil

        def tune # :nodoc:
        end

        private

        def secret = nil
      end
    RUBY
  end

  it 'lists public, documented names with their signatures, sorted' do
    expect(lines_for(source)).to eq(
      [
        'Gear (class)',
        'Gear#turn',
        'Widget (class < Base)',
        'Widget include Comparable',
        'Widget#color -> value',
        'Widget#color(value) -> self',
        'Widget#name (attr_reader)',
        'Widget#spin',
        'Widget.build(name, size: SIZE, &)',
        'Widget::SIZE'
      ]
    )
  end

  it 'leaves out what .rdoc_options excludes' do
    lines = lines_for(source, rdoc_options: "---\nexclude:\n  - lib/internal/\n")

    expect(lines).not_to include(start_with('Gear'))
    expect(lines).to include('Widget#spin')
  end
end
