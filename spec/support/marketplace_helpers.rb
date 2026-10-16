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
        add_pax_header(gzip, 'pax_global_header', 'g', "52 comment=#{commit}\n") if commit
        files.each { |path, content| add_entry(tar, gzip, "#{root}/#{path}", content) }
      end
    end
    io.string
  end

  def stub_repository(repository, files, ref: 'HEAD', **)
    stub_request(:get, "https://codeload.github.com/#{repository}/tar.gz/#{ref}")
      .to_return(status: 200, body: archive(files, **))
  end

  private

  def add_entry(tar, io, path, content)
    if path.length > 100
      record = " path=#{path}\n"
      add_pax_header(io, 'long.paxheader', 'x', "#{record.bytesize + 2}#{record}")
      path = 'long.data'
    end
    case content
    when Symbol then tar.add_symlink(path, content.to_s, 0o777)
    when Array then tar.add_file_simple(path, content.first, content.last.bytesize) { |file| file.write(content.last) }
    else tar.add_file_simple(path, 0o644, content.bytesize) { |file| file.write(content) }
    end
  end

  def add_pax_header(io, name, typeflag, content)
    header = Gem::Package::TarHeader.new(name:, typeflag:, size: content.bytesize, mode: 0o644, prefix: '',
                                         mtime: Time.at(0))
    io.write(header.to_s)
    io.write(content.ljust((content.bytesize / 512.0).ceil * 512, "\0"))
  end
end
