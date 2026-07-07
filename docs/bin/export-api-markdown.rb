# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'tmpdir'

output_dir = ARGV.fetch(0) do
  abort 'usage: export-api-markdown.rb <output-dir>'
end

repo = File.expand_path('../..', __dir__)
output_dir = File.expand_path(output_dir, repo)
rdoc = Gem.bin_path('rdoc', 'rdoc')
ri = Gem.bin_path('rdoc', 'ri')

def run!(*command, chdir:)
  _stdout, stderr, status = Open3.capture3(*command, chdir: chdir)
  return if status.success?

  abort "#{command.join(' ')} failed\n#{stderr}"
end

def capture!(*command, chdir:)
  stdout, stderr, status = Open3.capture3(*command, chdir: chdir)
  abort "#{command.join(' ')} failed\n#{stderr}" unless status.success?

  stdout
end

def markdown_path(api_name)
  "#{api_name.gsub('::', '/')}.md"
end

def clean_markdown(markdown, ri_dir)
  markdown
    .gsub(/\s*\(from\s+#{Regexp.escape(ri_dir)}\)/m, '')
    .gsub(%r{<code>(.*?)</code>}m, '`\1`')
    .gsub(/[ \t]+$/, '')
    .gsub(/\n{3,}/, "\n\n")
    .strip
end

FileUtils.mkdir_p(output_dir)

Dir.mktmpdir('ruby-llm-rdoc-ri') do |tmp_dir|
  ri_dir = File.join(tmp_dir, 'ri')

  run!(rdoc, '--format', 'ri', '--output', ri_dir, '--quiet', 'lib', chdir: repo)

  names = capture!(
    ri,
    '--no-standard-docs',
    '--doc-dir', ri_dir,
    '--format', 'markdown',
    '--width', '1000',
    '--list',
    chdir: repo
  ).lines.map(&:strip).reject(&:empty?).sort

  index = [
    '# RubyLLM API Reference',
    '',
    '<!-- Generated from RDoc by docs/bin/export-api-markdown.rb. Do not edit. -->',
    '',
    'Markdown pages for every public RubyLLM class and module.',
    ''
  ]

  names.each do |name|
    path = markdown_path(name)
    destination = File.join(output_dir, path)
    FileUtils.mkdir_p(File.dirname(destination))

    markdown = capture!(
      ri,
      '--no-standard-docs',
      '--doc-dir', ri_dir,
      '--format', 'markdown',
      '--width', '1000',
      '--all',
      name,
      chdir: repo
    )

    File.write(
      destination,
      "#{clean_markdown(markdown, ri_dir)}\n",
      mode: 'w',
      encoding: 'UTF-8'
    )

    index << "- [#{name}](#{path})"
  end

  File.write(
    File.join(output_dir, 'index.md'),
    "#{index.join("\n")}\n",
    mode: 'w',
    encoding: 'UTF-8'
  )
end
