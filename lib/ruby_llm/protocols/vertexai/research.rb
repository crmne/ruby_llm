# frozen_string_literal: true

module RubyLLM
  module Protocols
    module VertexAI
      # Single-turn hosted Deep Research through Vertex AI Interactions.
      class Research < Interactions
        STATUSES = {
          'queued' => :pending, 'in_progress' => :pending, 'completed' => :completed,
          'incomplete' => :incomplete, 'budget_exceeded' => :incomplete,
          'failed' => :failed, 'cancelled' => :cancelled
        }.freeze
        SERVER_TOOL_ALIASES = {
          mcp: { tool: { type: 'mcp_server' } },
          web_search: { tool: { type: 'google_search' } }
        }.freeze
        private_constant :STATUSES

        MCP_OPTIONS = %i[type name url headers allowed_tools].freeze
        private_constant :MCP_OPTIONS

        def server_tool_aliases = SERVER_TOOL_ALIASES

        def create_research_job(prompt, agent:, with: nil, provider_tools: nil, provider_options: {})
          payload = render_research_payload(prompt, agent:, with:, provider_tools:, provider_options:)
          response = @connection.post(research_url, payload, idempotent: false)
          parse_research_job(response, agent:)
        end

        def find_research_job(id)
          response = @connection.get(research_url(id))
          parse_research_job(response, id:)
        end

        def refresh_research_job(job, timeout: nil)
          response = @connection.get(research_url(job.id)) do |request|
            request.options.timeout = request_timeout(timeout)
          end
          parse_research_state(response)
        end

        def cancel_research_job(job, timeout: nil)
          response = @connection.post("#{research_url(job.id)}/cancel", {}, idempotent: false) do |request|
            request.options.timeout = request_timeout(timeout)
          end
          parse_research_state(response)
        end

        private

        def research_url(id = nil)
          unless @config.vertexai_location == 'global'
            raise ArgumentError, 'Vertex AI hosted research requires vertexai_location = "global"'
          end

          path = "#{@provider.location_path}/interactions"
          return path if id.nil?
          raise ArgumentError, 'Research job ID must not be empty' if id.to_s.empty?

          "#{path}/#{URI.encode_www_form_component(id)}"
        end

        def request_timeout(timeout)
          [timeout, @config.request_timeout].compact.min
        end

        def render_research_payload(prompt, agent:, with:, provider_tools:, provider_options:)
          raise ArgumentError, 'Research requires a nonempty prompt' unless prompt.is_a?(String) && !prompt.empty?

          attachments = Attachment.wrap(with, config: @config)
          payload = { agent:, input: render_interaction_content(prompt, attachments), background: true, stream: false }
          payload[:tools] = [] unless provider_tools.nil?
          options = render_research_options(provider_options)
          entries = if provider_tools.is_a?(Hash)
                      RubyLLM::Tools::ProviderTools.normalize([], provider_tools)
                    else
                      RubyLLM::Tools::ProviderTools.normalize(Array(provider_tools), {})
                    end
          apply_provider_tools(payload, resolve_provider_tools_for_request(entries)).merge(options)
        end

        def render_research_options(provider_options)
          options = Support::Utils.deep_symbolize_keys(provider_options)
          unsupported = options.keys - %i[agent_config service_tier]
          unless unsupported.empty?
            raise ArgumentError,
                  "Vertex AI research options only support agent_config and service_tier: #{unsupported.join(', ')}"
          end

          options
        end

        def merge_server_tool_entries(payload, entries)
          normalized = entries.map { |entry| Support::Utils.deep_symbolize_keys(entry) }
          normalized.each do |entry|
            next unless entry[:type].to_s == 'mcp_server'

            unsupported = entry.keys - MCP_OPTIONS
            next if unsupported.empty?

            raise ArgumentError, "Vertex AI research MCP does not support: #{unsupported.join(', ')}"
          end
          super(payload, normalized)
        end

        def parse_research_job(response, agent: nil, id: nil)
          data = response.body
          state = parse_research_state(response)
          ResearchJob.new(id: data['id'], provider: @provider.slug, agent: data['agent'] || agent, protocol: self,
                          **state)
        rescue RubyLLM::Error, ArgumentError => e
          identifier = id || (data['id'] if data.is_a?(Hash))
          raise if identifier.to_s.empty?

          returned_agent = data['agent'] if data.is_a?(Hash)
          job = ResearchJob.new(id: identifier, provider: @provider.slug, agent: agent || returned_agent,
                                protocol: self, status: :pending, raw: data)
          raise ResearchJob::Error.new("Research returned an invalid job response (job #{identifier}): #{e.message}",
                                       job:, response:), cause: e
        end

        def parse_research_state(response)
          data = response.body
          validate_research_response(data, response)
          status = STATUSES.fetch(data['status'])
          message = parse_research_message(data, response) if %i[completed incomplete].include?(status)
          {
            status:, raw: data, message:,
            error: parse_research_error(data), tokens: parse_research_tokens(data)
          }
        end

        def validate_research_response(data, response)
          return if data.is_a?(Hash) && !data['id'].to_s.empty? && STATUSES.key?(data['status'])

          raise RubyLLM::Error.new('Vertex AI research returned no recognized job state', response:)
        end

        def parse_research_tokens(data)
          fields = parse_interaction_usage(data['usage'] || {}).transform_keys do |key|
            key.to_s.delete_suffix('_tokens').to_sym
          end
          Tokens.new(**fields)
        end

        def parse_research_message(data, response)
          state = data.merge('status' => data['status'] == 'completed' ? 'completed' : 'incomplete')
          tokens = parse_research_tokens(data)
          cost = Cost.from_h({ total: tokens.reported_cost }.compact, tokens:)
          parse_completion_body(state, raw: response, model: nil, cost:)
        end

        def parse_research_error(data)
          errors = Array(data['errors']).filter_map { |error| error['message'] }
          errors << (data['error'].is_a?(Hash) ? data['error']['message'] : data['error']) if data['error']
          errors.join('; ') unless errors.empty?
        end
      end
    end
  end
end
