# frozen_string_literal: true

# The object a prompt template is evaluated in. Locals become local
# variables of the template, and +render+ inserts a partial.
#
# The class is declared with its full name so the template binding has no
# RubyLLM lexical scope: +Chat+ in a template is the application's model,
# not RubyLLM::Chat.
class RubyLLM::Prompt::Context # rubocop:disable Style/ClassAndModuleChildren
  def initialize(prompt, locals) # :nodoc:
    @prompt = prompt
    @locals = locals
  end

  # Renders the partial +name+ with +locals+. The partial is looked up next
  # to the current prompt first, then in every prompt root.
  #
  #   <%= render "shared/safety", product_name: product_name %>
  #
  def render(name, **locals)
    partial(name).render(**locals)
  end

  def scope # :nodoc:
    @locals.each_with_object(binding) { |(name, value), scope| scope.local_variable_set(name, value) }
  end

  private

  def partial(name)
    candidates = partial_names(name).map { |candidate| RubyLLM::Prompt.new(candidate) }
    candidates.find { |candidate| File.exist?(candidate.path) } || candidates.first
  end

  def partial_names(name)
    partial = name.to_s.sub(%r{([^/]+)\z}, '_\\1')
    directory = File.dirname(@prompt.name)
    directory == '.' ? [partial] : ["#{directory}/#{partial}", partial]
  end
end
