# frozen_string_literal: true

module RubyLLM
  # Adds workflow and step context to RubyLLM instrumentation while leaving
  # orchestration in ordinary Ruby code.
  #
  # Create workflows through RubyLLM.workflow rather than constructing this
  # class directly:
  #
  #   RubyLLM.workflow("Write article", id: "article-42") do |workflow|
  #     notes = workflow.step("Research") { ResearchAgent.new.ask(topic).content }
  #     workflow.step("Draft") { WriterAgent.new.ask(notes).content }
  #   end
  #
  class Workflow
    attr_reader :id, :name

    def initialize(name, id: nil, metadata: nil, config: RubyLLM.config) # :nodoc:
      @name = normalize(name, 'name')
      @id = normalize(id || SecureRandom.uuid, 'id')
      @metadata = metadata
      @config = config
    end

    def run
      raise ArgumentError, 'a workflow block is required' unless block_given?

      link_parent
      Instrumentation.with_workflow(workflow_context) do
        RubyLLM.instrument('workflow.ruby_llm', config: @config) { yield self }
      end
    end

    # Runs a named section of Ruby code and adds its identity to every RubyLLM
    # event emitted by the block. An ID is generated when one is not supplied.
    # Steps can contain regular Ruby control flow and may be nested.
    def step(name, id: nil, &block)
      raise ArgumentError, 'a workflow step block is required' unless block

      step_context = workflow_context.merge(
        workflow_step_id: normalize(id || SecureRandom.uuid, 'step id'),
        workflow_step_name: normalize(name, 'step name')
      )
      parent_id = current_step_id
      step_context[:workflow_step_parent_id] = parent_id if parent_id

      Instrumentation.with_workflow(step_context.freeze) do
        RubyLLM.instrument('workflow_step.ruby_llm', config: @config) { block.call }
      end
    end

    private

    def workflow_context
      @workflow_context ||= begin
        context = { workflow_id: id, workflow_name: name }
        context[:workflow_metadata] = @metadata unless @metadata.nil?
        context.freeze
      end
    end

    def link_parent
      current = Instrumentation.current_workflow
      return unless current && current[:workflow_id] != id

      context = workflow_context.dup
      context[:workflow_parent_id] = current[:workflow_id]
      context[:workflow_parent_step_id] = current[:workflow_step_id] if current[:workflow_step_id]
      @workflow_context = context.freeze
    end

    def current_step_id
      current = Instrumentation.current_workflow
      current[:workflow_step_id] if current && current[:workflow_id] == id
    end

    def normalize(value, attribute)
      value = value.to_s
      raise ArgumentError, "workflow #{attribute} cannot be empty" if value.empty?

      value
    end
  end
end
