# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::CodeExecution::Workspace do
  def attachment(content, filename = 'report.txt')
    RubyLLM::Attachment.new(StringIO.new(content), filename:)
  end

  def copied(*attachments)
    described_class.open do |workspace|
      workspace.copy_in(attachments)
      Dir.children(workspace.inputs).sort.to_h do |name|
        [name, File.read(File.join(workspace.inputs, name))]
      end
    end
  end

  it 'keeps both files that share a name, the newest under that name' do
    expect(copied(attachment('first'), attachment('second')))
      .to eq('report.txt' => 'second', 'report-2.txt' => 'first')
  end

  it 'numbers past a name already taken' do
    files = [attachment('a'), attachment('b'), attachment('c', 'report-2.txt')]

    expect(copied(*files)).to eq('report-2.txt' => 'c', 'report.txt' => 'b', 'report-3.txt' => 'a')
  end

  it 'numbers past a name that differs only in case' do
    files = [attachment('a'), attachment('b'), attachment('c', 'REPORT-2.TXT')]

    expect(copied(*files)).to eq('REPORT-2.TXT' => 'c', 'report-3.txt' => 'a', 'report.txt' => 'b')
  end

  it 'reports the name a file ended up with, sharing one for equal content' do
    same = attachment('x', 'Report.txt')
    twin = attachment('x', 'report.txt')

    expect(described_class.input_names([same, twin]).values).to eq(%w[report.txt report.txt])
  end

  it 'never numbers a file into a folder another input needs' do
    files = [attachment('a'), attachment('b'), attachment('c', 'report-2.txt/part')]

    expect { described_class.open { |workspace| workspace.copy_in(files) } }.not_to raise_error
    expect(described_class.input_names(files).values).to contain_exactly('report-2.txt/part', 'report.txt',
                                                                         'report-3.txt')
  end

  it 'leaves provider files out of the names' do
    file = attachment('a')
    allow(file).to receive(:provider_file?).and_return(true)

    expect(described_class.input_names([file])).to be_empty
  end

  it 'numbers a file with no extension' do
    expect(copied(attachment('a', 'notes'), attachment('b', 'notes'))).to eq('notes' => 'b', 'notes-2' => 'a')
  end

  it 'copies the same file attached twice once' do
    expect(copied(attachment('same'), attachment('same'))).to eq('report.txt' => 'same')
  end

  it 'reports an output whose name is not valid UTF-8 as skipped' do
    described_class.open do |workspace|
      File.binwrite(File.join(workspace.directory, "bad\xFFname.txt".b), 'x')
      File.binwrite(File.join(workspace.directory, 'kept.txt'), 'y')

      files, skipped = workspace.outputs(max_files: 10, max_size: 100)

      expect(files.map(&:filename)).to eq(['kept.txt'])
      expect(skipped).to eq(["bad\uFFFDname.txt (name is not valid UTF-8)"])
    end
  end
end
