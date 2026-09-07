# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Cohere
      # Cohere datasets for batch input and generated results.
      class Datasets < Protocols::Files
        def upload(file, filename: nil, purpose: nil, expires_in: nil, uri: nil, content_type: nil,
                   provider_options: {})
          raise ArgumentError, 'Cohere datasets require purpose: with a dataset type' unless purpose
          raise ArgumentError, 'Cohere datasets do not accept expires_in or uri' if expires_in || uri

          attachment = file_attachment(file, filename:)
          options = { name: attachment.filename, type: purpose, keep_original_file: true }
                    .merge(provider_options.transform_keys(&:to_sym))
          response = @connection.post('v1/datasets', { data: file_part(attachment, content_type:) },
                                      idempotent: false) do |request|
            request.headers.delete('Content-Type')
            request.params.update(options)
          end
          find(response.body.fetch('id'))
        end

        def download(file_id)
          file = wait_for_validation(file_id)
          parts = dataset_parts(file.metadata)
          originals = parts.filter_map { |part| part['original_url'] }.uniq
          if parts.any? && parts.all? { |part| part['original_url'] }
            return originals.map do |url|
              download_part(url)
            end.join
          end

          records(file).map { |row| "#{JSON.generate(row)}\n" }.join
        end

        def records(file)
          load_avro
          dataset_parts(file.metadata).flat_map do |part|
            reader = nil
            content = StringIO.new(download_part(part.fetch('url')))
            reader = Avro::DataFile::Reader.new(content, Avro::IO::DatumReader.new)
            reader.to_a
          ensure
            reader&.close
          end
        end

        def wait_for_validation(id)
          deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + @config.request_timeout
          loop do
            file = find(id)
            return file if file.status == 'validated'
            if file.status == 'failed'
              raise Error, "Cohere dataset #{id} failed validation: #{file.metadata['validation_error']}"
            end
            if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
              raise Error, "Cohere dataset validation timed out: #{id}"
            end

            sleep 1
          end
        end

        private

        def files_url
          'v1/datasets'
        end

        def parse_file_response(response)
          data = response.fetch('dataset')
          parts = dataset_parts(data)
          original = parts.first&.fetch('original_url', nil)
          filename = original ? File.basename(URI.parse(original).path) : "#{data.fetch('name')}.jsonl"
          mime_type = if File.extname(filename) == '.jsonl'
                        'application/jsonl'
                      else
                        RubyLLM::Files::MimeType.for(name: filename)
                      end
          uploaded_file(data, id: data.fetch('id'), filename:, mime_type:,
                              created_at: timestamp(data['created_at']), status: data['validation_status'],
                              purpose: data['dataset_type'], downloadable: !parts.empty?)
        end

        def dataset_parts(data)
          Array(data['dataset_parts']).sort_by.with_index { |part, index| part.fetch('index', index) }
        end

        def download_part(url)
          Transport::Connection.basic(@config).get(url).body
        end

        def load_avro
          require 'avro'
        rescue LoadError
          raise LoadError, 'Add gem "avro" to your Gemfile to read Cohere batch results and processed datasets'
        end
      end
    end
  end
end
