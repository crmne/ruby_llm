# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'rbconfig'
require 'tempfile'

module RubyLLM
  module ModelRegistry # :nodoc: all
    PUBLISHED_URL = 'https://rubyllm.com/models.json'

    class FileStore
      attr_reader :path

      def initialize(path)
        @path = path.respond_to?(:path) ? path.path : path.to_s
        raise ModelRegistryError, 'A model registry file path is required' if @path.empty?
      end

      def read
        ModelRegistry.read(path)
      end

      def etag
        return unless File.file?(path)

        value = File.read(etag_path).strip
        value unless value.empty?
      rescue Errno::ENOENT
        nil
      rescue SystemCallError => e
        raise ModelRegistryError, "Could not read the model registry ETag from #{etag_path}: #{e.message}"
      end

      def write(models, etag: nil)
        FileUtils.mkdir_p(File.dirname(path))
        atomic_write(path, ModelRegistry.pretty_json(models))
        write_etag(etag)
        models
      end

      private

      def etag_path
        "#{path}.etag"
      end

      def write_etag(etag)
        if etag
          atomic_write(etag_path, "#{etag}\n")
        else
          FileUtils.rm_f(etag_path)
        end
      end

      def atomic_write(destination, contents)
        directory = File.dirname(destination)
        basename = File.basename(destination)
        Tempfile.create([basename, '.tmp'], directory) do |temporary|
          temporary.binmode
          temporary.write(contents)
          temporary.flush
          temporary.fsync
          replace_file(temporary.path, destination)
        end
      end

      def replace_file(source, destination)
        File.rename(source, destination)
      rescue Errno::EACCES, Errno::EEXIST
        FileUtils.rm_f(destination)
        File.rename(source, destination)
      end
    end

    class PublishedSource
      Result = Struct.new(:models, :etag, :not_modified)

      attr_reader :url

      def initialize(url = PUBLISHED_URL)
        @url = url
      end

      def fetch(etag: nil)
        connection = Connection.basic do |faraday|
          faraday.response :json, parser_options: { symbolize_names: true }
        end
        response = connection.get(url) do |request|
          request.headers['If-None-Match'] = etag if etag
        end

        return Result.new(nil, response.headers['etag'] || etag, true) if response.status == 304

        models = ModelRegistry.models_from_data(response.body, source: url)
        raise ModelRegistryError, 'Published model registry is empty' if models.empty?

        Result.new(models, response.headers['etag'], false)
      rescue ModelRegistryError
        raise
      rescue StandardError => e
        raise ModelRegistryError, "Could not refresh the model registry from #{url}: #{e.message}"
      end
    end

    module_function

    def read(file)
      data = JSON.parse(File.read(file), symbolize_names: true)
      models_from_data(data, source: file)
    rescue Errno::ENOENT
      nil
    rescue JSON::ParserError => e
      raise ModelRegistryError, "Invalid model registry JSON in #{file}: #{e.message}"
    rescue SystemCallError => e
      raise ModelRegistryError, "Could not read the model registry from #{file}: #{e.message}"
    end

    def models_from_data(data, source: nil)
      unless data.is_a?(Array)
        location = source ? " in #{source}" : ''
        raise ModelRegistryError, "Model registry#{location} must be a JSON array"
      end

      data.map { |model| model.is_a?(Model) ? model : Model.new(model) }
    end

    def pretty_json(models)
      "#{JSON.pretty_generate(Array(models).map(&:to_h))}\n"
    end

    def cache_path
      home = Dir.home
      host_os = RbConfig::CONFIG['host_os']

      directory = if host_os.match?(/darwin/i)
                    File.join(home, 'Library', 'Caches', 'RubyLLM')
                  elsif host_os.match?(/mswin|mingw|cygwin/i)
                    local_app_data = ENV.fetch('LOCALAPPDATA', nil)
                    local_app_data = File.join(home, 'AppData', 'Local') if local_app_data.to_s.empty?
                    File.join(local_app_data, 'RubyLLM', 'Cache')
                  else
                    xdg_cache = ENV.fetch('XDG_CACHE_HOME', nil)
                    xdg_cache = File.join(home, '.cache') if xdg_cache.to_s.empty?
                    File.join(xdg_cache, 'ruby_llm')
                  end

      File.join(directory, 'models.json')
    rescue ArgumentError
      # Dir.home raises when the home directory cannot be determined.
      nil
    end
  end
end
