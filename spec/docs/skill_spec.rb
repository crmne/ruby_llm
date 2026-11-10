# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'skills/rubyllm', type: :task do
  let(:root) { File.expand_path('../../skills/rubyllm', __dir__) }
  let(:skill) { File.read(File.join(root, 'SKILL.md')) }

  it 'keeps the file every session reads short' do
    expect(skill.bytesize).to be <= 18_000
  end

  it 'names every reference that exists, and only those' do
    named = skill.scan(%r{references/[\w-]+\.md}).uniq
    present = Dir.glob('references/*.md', base: root)

    expect(named).to match_array(present)
  end

  it 'keeps each reference short enough to read in one call' do
    Dir.glob(File.join(root, 'references/*.md')).each do |path|
      expect(File.size(path)).to be <= 8_000
    end
  end
end
