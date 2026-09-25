# frozen_string_literal: true

# The object a prompt template is evaluated in. Locals become local
# variables of the template, and +render+ inserts a partial.
#
# The class is declared with its full name so the template binding has no
# RubyLLM lexical scope: +Chat+ in a template is the application's model,
# not RubyLLM::Chat.
class RubyLLM::Prompt::Context # rubocop:disable Style/ClassAndModuleChildren
  LOCAL_VARIABLE_NAME = /\A(?![A-Z0-9])(?:[[:alnum:]_]|[^\0-\177])+\z/
  private_constant :LOCAL_VARIABLE_NAME

  # Returns the locals passed to the current prompt or partial. Use it to
  # read an optional local, or a local whose name is not a valid Ruby
  # variable name:
  #
  #   <% if local_assigns[:product_name] %>
  #
  attr_reader :local_assigns

  def initialize(prompt, local_assigns) # :nodoc:
    @prompt = prompt
    @local_assigns = local_assigns
  end

  # Renders a partial with locals. A bare name is looked up next to the
  # current prompt only. A name with a path is looked up in the prompt roots.
  #
  #   <%= render "tone" %>
  #   <%= render "shared/safety", product_name: product_name %>
  #   <%= render partial: "shared/safety", locals: { product_name: product_name } %>
  #
  def render(options = {}, locals = {})
    return partial(options).render(**locals) unless options.is_a?(Hash)

    partial(options.fetch(:partial)).render(**(options[:locals] || {}))
  end

  def scope # :nodoc:
    @local_assigns.each_with_object(binding) do |(name, value), scope|
      scope.local_variable_set(name, value) if name.to_s.match?(LOCAL_VARIABLE_NAME)
    end
  end

  private

  def partial(name)
    name = name.to_s
    partial = name.sub(%r{([^/]+)\z}, '_\\1')
    directory = File.dirname(@prompt.name)
    return RubyLLM::Prompt.new(partial) if name.include?('/') || directory == '.'

    RubyLLM::Prompt.new("#{directory}/#{partial}")
  end
end
