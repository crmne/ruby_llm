# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # View helpers for a chat's page, available in every view of a Rails
    # app. The views <tt>bin/rails generate ruby_llm:chat_ui</tt> writes use
    # them.
    #
    #   <%= render tool_call_partial(tool_call), message:, tool_call: %>
    #   Cost so far: <%= cost_label(@chat.cost) %>
    #
    # To change one, define a method with the same name in a helper of
    # your own, such as +app/helpers/messages_helper.rb+: it takes the
    # place of RubyLLM's. An app whose chat UI was generated before
    # RubyLLM shipped these keeps the +MessagesHelper+ the generator wrote,
    # and its methods win the same way.
    #
    module ChatHelper
      # Returns the label of the configured default model, such as
      # "Default: GPT-6.1 Sol", for the empty choice of a model picker.
      def default_model_display_name
        "Default: #{RubyLLM.models.find(RubyLLM.config.default_model).label}"
      end

      # Returns +cost+, a RubyLLM::Cost, in US dollars to four decimal
      # places, such as "$0.0123". RubyLLM prices every cost in US dollars,
      # so the label is in dollars whatever the app's locale.
      def cost_label(cost)
        number_to_currency(cost.total, unit: '$', precision: 4)
      end

      # Returns the partial that renders +tool_call+, a RubyLLM::ToolCall:
      # the one named after its tool in the +tool_calls+ folder beside the
      # current template, as <tt>bin/rails generate ruby_llm:tool</tt>
      # writes it, or that folder's +default+ partial.
      #
      #   tool_call_partial(tool_call) # => "messages/tool_calls/weather"
      #
      def tool_call_partial(tool_call)
        ruby_llm_tool_partial('tool_calls', tool_call.name)
      end

      # Returns the partial that renders +message+, a tool result, from
      # the +tool_results+ folder beside the current template, as
      # #tool_call_partial does for a call.
      def tool_result_partial(message)
        ruby_llm_tool_partial('tool_results', message.try(:parent_tool_call)&.name)
      end

      # Returns a tool's +name+ for a person to read, such as "Weather"
      # for +weather+, or "Tool" without one.
      def tool_label(name)
        name.to_s.humanize.presence || 'Tool'
      end

      # Returns the label of the tool whose result +message+ holds. See
      # #tool_label.
      def tool_result_label(message)
        tool_label(message.try(:parent_tool_call)&.name)
      end

      private

      def ruby_llm_tool_partial(folder, name)
        prefix = File.join(File.dirname(@virtual_path.to_s), folder)
        partial = name.to_s.underscore.tr('-', '_')
        return "#{prefix}/default" unless partial.present? && lookup_context.exists?(partial, [prefix], true)

        "#{prefix}/#{partial}"
      end
    end
  end
end
