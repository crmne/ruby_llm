# frozen_string_literal: true

# Whether the temporary directory keeps a file name that is not valid UTF-8.
# Some filesystems keep the bytes they are given; others, such as APFS,
# refuse the name.
module FileNames
  module_function

  def non_utf8?
    Dir.mktmpdir do |directory|
      File.binwrite(File.join(directory, "\xFF".b), '')
      Dir.children(directory, encoding: Encoding::UTF_8).none?(&:valid_encoding?)
    end
  rescue SystemCallError
    false
  end
end
