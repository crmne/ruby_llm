# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::StoredFile do
  def file(byte_size: 10, **attributes)
    described_class.new(path: 'reports/q3.pdf', byte_size:, content_type: 'application/pdf', digest: 'abc',
                        **attributes)
  end

  it 'reads its file name and whether it is text' do
    expect(file.filename).to eq('q3.pdf')
    expect(file).not_to be_text
    expect(described_class.new(path: 'a.csv', byte_size: 1, content_type: 'text/csv')).to be_text
  end

  it 'gives its size for people to read' do
    sizes = [0, 1, 512, 1536, 5 * (1024**2), 3 * (1024**3), 2 * (1024**4), 1024**6]

    expect(sizes.map { |byte_size| file(byte_size:).human_size })
      .to eq(['0 bytes', '1 byte', '512 bytes', '1.5 KB', '5.0 MB', '3.0 GB', '2.0 TB', '1048576.0 TB'])
  end

  it 'equals a file with the same path, size, type, and digest, whenever and by whomever it was written' do
    same = file(updated_at: Time.now, owner: :someone)

    expect(file).to eq(same)
    expect(file).to eql(same)
    expect(file.hash).to eq(same.hash)
    expect(file).not_to eq(file(byte_size: 11))
    expect(file).not_to eq(file.to_h)
  end

  it 'turns into a Hash and inspects in one line' do
    expect(file.to_h).to eq(path: 'reports/q3.pdf', byte_size: 10, content_type: 'application/pdf', digest: 'abc',
                            updated_at: nil, owner: nil)
    expect(file.inspect)
      .to eq('#<RubyLLM::StoredFile path: "reports/q3.pdf", byte_size: 10, content_type: "application/pdf">')
  end
end
