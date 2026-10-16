# frozen_string_literal: true

require 'rubygems/package'
require 'stringio'
require 'zlib'

module MarketplaceHelpers
  COMMIT = '3bf9a60e6aef758c77cff9067a62f7f85a38eeb1'

  def write_file(path, content)
    path.dirname.mkpath
    path.write(content)
    path
  end

  def write_skill(folder, name: folder.basename.to_s, description: "Does #{name}.")
    write_file(folder.join('SKILL.md'), "---\nname: #{name}\ndescription: #{description}\n---\nFollow #{name}.\n")
    folder
  end

  def write_marketplace(directory, plugins, name: 'acme-skills', file: '.claude-plugin/marketplace.json', **fields)
    write_file(directory.join(file), JSON.generate({ name:, plugins:, **fields }))
    directory
  end

  def archive(files, commit: COMMIT, root: 'repo-main')
    io = StringIO.new
    Zlib::GzipWriter.wrap(io) do |gzip|
      Gem::Package::TarWriter.new(gzip) do |tar|
        tar.add_file_simple('pax_global_header', 0o644, 52) { |file| file.write("52 comment=#{commit}\n") } if commit
        files.each { |path, content| add_entry(tar, "#{root}/#{path}", content) }
      end
    end
    io.string
  end

  def stub_repository(repository, files, ref: 'HEAD', **)
    stub_request(:get, "https://codeload.github.com/#{repository}/tar.gz/#{ref}")
      .to_return(status: 200, body: archive(files, **))
  end

  private

  def add_entry(tar, path, content)
    case content
    when Symbol then tar.add_symlink(path, content.to_s, 0o777)
    when Array then tar.add_file_simple(path, content.first, content.last.bytesize) { |file| file.write(content.last) }
    else tar.add_file_simple(path, 0o644, content.bytesize) { |file| file.write(content) }
    end
  end
end
