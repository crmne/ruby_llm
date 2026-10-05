# frozen_string_literal: true

require 'yaml'
require 'pathname'

module RubyLLM
  class Evaluation
    module Dataset # :nodoc:
      module_function

      def load(source, name:)
        source = rows(source, name:)
        cases = source.map do |row|
          row.is_a?(Case) ? row : Case.new(**row.transform_keys(&:to_sym))
        end
        raise ArgumentError, 'A dataset cannot be empty' if cases.empty?
        raise ArgumentError, 'Dataset case names must be unique' unless cases.map(&:name).uniq.size == cases.size

        cases
      end

      def rows(source, name:)
        source = source.call if source.respond_to?(:call)
        source ||= discover(name)
        source = read(source) if source.is_a?(String) || source.is_a?(Pathname)
        source = cases_from_hash(source) if source.is_a?(Hash)
        raise ArgumentError, 'A dataset must contain enumerable cases' unless source.respond_to?(:map)

        source
      end

      def cases_from_hash(source)
        unknown = source.keys.map(&:to_s) - %w[name cases]
        if unknown.any?
          raise ArgumentError,
                "Unsupported dataset fields: #{unknown.join(', ')}; declare evaluators in Ruby"
        end

        source.fetch('cases') { source.fetch(:cases) }
      end

      def discover(name)
        raise ArgumentError, 'An anonymous evaluation needs an explicit dataset' unless name

        filename = name.gsub('::', '/').gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                       .gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
        root = Prompt.root.parent.join('evals')
        paths = %w[yml yaml json jsonl].map { |extension| root.join("#{filename}.#{extension}") }.select(&:file?)
        raise ArgumentError, "Dataset not found: #{root.join(filename)}.{yml,yaml,json,jsonl}" if paths.empty?
        raise ArgumentError, "Ambiguous dataset: #{paths.join(', ')}" if paths.size > 1

        paths.first
      end

      def read(path)
        case File.extname(path)
        when '.yml', '.yaml' then YAML.safe_load_file(path, aliases: false)
        when '.json' then JSON.parse(File.read(path))
        when '.jsonl' then File.foreach(path).reject { |line| line.strip.empty? }.map { |line| JSON.parse(line) }
        else raise ArgumentError, "Unsupported dataset format: #{path}"
        end
      end
    end
  end
end
