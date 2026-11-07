# frozen_string_literal: true

require 'rdoc'

# Lists RubyLLM's public API from RDoc's own parse of lib/, honouring
# .rdoc_options and :nodoc:, so the list matches the published API reference.
# One line per class, module, mixin, constant, attribute, and method
# signature, sorted, so a change to the public surface shows up as a diff.
class PublicApi
  ROOT = File.expand_path('../..', __dir__)
  FILE = File.join(ROOT, 'api.txt')
  HEADER = [
    '# RubyLLM public API, generated from RDoc by `rake api:dump`. Do not edit.',
    '# A new or changed line needs the maintainer\'s approval; see AGENTS.md.'
  ].freeze

  def self.lines(root = ROOT)
    new(root).lines
  end

  def self.render(root = ROOT)
    [*HEADER, *lines(root)].join("\n") << "\n"
  end

  def initialize(root)
    @root = root
    return if Gem::Version.new(RDoc::VERSION) >= Gem::Version.new('8')

    abort "The public API list needs RDoc 8 or later (found #{RDoc::VERSION}): " \
          'older versions list private methods in concerns. Run `bundle update rdoc`.'
  end

  def lines
    store = parse
    store.all_classes_and_modules.select(&:display?).flat_map { |mod| describe(store, mod) }.uniq.sort
  end

  private

  def parse
    Dir.chdir(@root) do
      options = RDoc::Options.load_options
      options.files = ['lib']
      options.quiet = true
      options.finish
      store = RDoc::Store.new(options)
      rdoc = RDoc::RDoc.new
      rdoc.options = options
      rdoc.store = store
      rdoc.parse_files(options.files)
      store.complete(options.visibility)
      store
    end
  end

  def describe(store, mod)
    name = mod.full_name
    [
      declaration(store, mod),
      *mod.includes.map { |mixin| "#{name} include #{resolve(store, mod, mixin.name)}" },
      *mod.extends.map { |mixin| "#{name} extend #{resolve(store, mod, mixin.name)}" },
      *members(name, mod)
    ]
  end

  def members(name, mod)
    [
      *mod.constants.select(&:display?).map { |constant| "#{name}::#{constant.name}" },
      *mod.attributes.select { |attribute| shown?(attribute) }.map { |attribute| attribute_line(name, attribute) },
      *mod.method_list.select { |method| shown?(method) }.flat_map { |method| method_lines(name, method) }
    ]
  end

  def declaration(store, mod)
    return "#{mod.full_name} (module)" if mod.module?

    superclass = mod.superclass
    superclass = superclass.full_name unless superclass.nil? || superclass.is_a?(String)
    superclass = resolve(store, mod, superclass) if superclass
    return "#{mod.full_name} (class)" if superclass.nil? || superclass == 'Object'

    "#{mod.full_name} (class < #{superclass})"
  end

  def resolve(store, mod, name)
    return name.delete_prefix('::') if name.start_with?('::')

    scope = mod.full_name.split('::')
    until scope.empty?
      candidate = [*scope, name].join('::')
      return candidate if store.find_class_or_module(candidate)

      scope.pop
    end
    name
  end

  def shown?(member)
    member.display? && member.visibility == :public
  end

  def attribute_line(owner, attribute)
    kind = { 'R' => 'attr_reader', 'W' => 'attr_writer', 'RW' => 'attr_accessor' }.fetch(attribute.rw)
    "#{owner}#{separator(attribute)}#{attribute.name} (#{kind})"
  end

  def method_lines(owner, method)
    prefix = "#{owner}#{separator(method)}"
    if method.call_seq
      method.call_seq.lines.map(&:strip).reject(&:empty?).map { |variant| "#{prefix}#{squish(variant)}" }
    else
      ["#{prefix}#{method.name}#{squish(method.params.to_s)}"]
    end
  end

  def separator(member)
    member.singleton ? '.' : '#'
  end

  def squish(text)
    text.gsub(/\s+/, ' ').strip.sub(/\A\(\)\z/, '')
  end
end
