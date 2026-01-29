# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::VertexAI::Embeddings do
  let(:test_class) do
    Class.new do
      include RubyLLM::Providers::VertexAI::Embeddings

      attr_reader :config

      def initialize(config)
        @config = config
      end
    end
  end

  let(:config) do
    double( # rubocop:disable RSpec/VerifiedDoubles
      'config',
      vertexai_project_id: 'test-project',
      vertexai_location: 'us-central1'
    )
  end

  let(:embeddings) do
    test_class.new(config)
  end

  describe '#embedding_url' do
    it 'constructs the correct URL' do
      url = embeddings.send(:embedding_url, model: 'multimodalembedding')
      expect(url).to eq(
        'projects/test-project/locations/us-central1/publishers/google/models/multimodalembedding:predict'
      )
    end
  end

  describe '#render_embedding_payload' do
    context 'with text only' do
      it 'renders single text payload with a text embedding model' do
        payload = embeddings.send(:render_embedding_payload, 'Hello!', model: 'gemini-embedding-001')
        expect(payload[:instances]).to eq([{ text: 'Hello!' }])
      end

      it 'renders single text payload with a multimodal embedding model' do
        payload = embeddings.send(:render_embedding_payload, 'Hello!', model: 'multimodalembedding')
        expect(payload[:instances]).to eq([{ text: 'Hello!' }])
      end

      it 'renders multiple batch text payloads' do
        payload = embeddings.send(:render_embedding_payload, ['Hello!', 'Hi there!'], model: 'text-embedding-005')
        expect(payload[:instances]).to eq([{ text: 'Hello!' }, { text: 'Hi there!' }])
      end
    end

    context 'with multimodal content payload' do
      it 'renders payload with image file' do
        image_file = Tempfile.new(['test_image', '.png'])
        image_file.write('fake_image_data')
        image_file.rewind

        payload = embeddings.send(
          :render_embedding_payload,
          'Test multimodal input',
          model: 'multimodalembedding',
          with: [image_file]
        )
        expect(payload[:instances].first[:text]).to eq('Test multimodal input')
        expect(payload[:instances].first).to have_key(:image)
        expect(payload[:instances].first).not_to have_key(:video)

        image_file.close
        image_file.unlink
      end

      it 'renders payload with video file' do
        video_file = Tempfile.new(['test_video', '.mp4'])
        video_file.write('fake_video_data')
        video_file.rewind

        payload = embeddings.send(
          :render_embedding_payload,
          'Test multimodal input',
          model: 'multimodalembedding',
          with: [video_file]
        )
        expect(payload[:instances].first[:text]).to eq('Test multimodal input')
        expect(payload[:instances].first).to have_key(:video)
        expect(payload[:instances].first).not_to have_key(:image)

        video_file.close
        video_file.unlink
      end

      it 'renders payload with GCS video URI' do
        payload = embeddings.send(
          :render_embedding_payload,
          'Test multimodal input',
          model: 'multimodalembedding',
          with: ['gs://my-bucket/my-video.mp4']
        )
        expect(payload[:instances].first[:text]).to eq('Test multimodal input')
        expect(payload[:instances].first).to have_key(:video)
        expect(payload[:instances].first).not_to have_key(:image)
      end

      it 'renders both image and video in payload' do
        image_file = Tempfile.new(['test_image', '.png'])
        image_file.write('fake_image_data')
        image_file.rewind

        video_file = Tempfile.new(['test_video', '.mp4'])
        video_file.write('fake_video_data')
        video_file.rewind

        payload = embeddings.send(
          :render_embedding_payload,
          'Test multimodal input',
          model: 'multimodalembedding',
          with: [image_file, video_file]
        )
        expect(payload[:instances].first[:text]).to eq('Test multimodal input')
        expect(payload[:instances].first).to have_key(:image)
        expect(payload[:instances].first).to have_key(:video)

        image_file.close
        image_file.unlink
        video_file.close
        video_file.unlink
      end

      it 'renders payload with no multimodal content' do
        payload = embeddings.send(
          :render_embedding_payload,
          'Test multimodal input',
          model: 'multimodalembedding'
        )
        expect(payload[:instances].first[:text]).to eq('Test multimodal input')
        expect(payload[:instances].first).not_to have_key(:image)
        expect(payload[:instances].first).not_to have_key(:video)
      end

      it 'raises error for unsupported file type' do
        unsupported_file = Tempfile.new(['test_unsupported', '.txt'])
        unsupported_file.write('some text data')
        unsupported_file.rewind

        expect do
          embeddings.send(
            :render_embedding_payload,
            'Test multimodal input',
            model: 'multimodalembedding',
            with: [unsupported_file]
          )
        end.to raise_error(ArgumentError, /Unsupported file type for file/)

        unsupported_file.close
        unsupported_file.unlink
      end

      it 'raises error for multiple images' do
        image_file1 = Tempfile.new(['test_image1', '.png'])
        image_file2 = Tempfile.new(['test_image2', '.jpg'])
        image_file1.write('fake_image_data_1')
        image_file2.write('fake_image_data_2')
        image_file1.rewind
        image_file2.rewind

        expect do
          embeddings.send(
            :render_embedding_payload,
            'Test multimodal input',
            model: 'multimodalembedding',
            with: [image_file1, image_file2]
          )
        end.to raise_error(ArgumentError, 'This model only supports one image at a time.')
        image_file1.close
        image_file1.unlink
        image_file2.close
        image_file2.unlink
      end

      it 'raises error for multiple videos' do
        video_file1 = Tempfile.new(['test_video1', '.mp4'])
        video_file2 = Tempfile.new(['test_video2', '.avi'])
        video_file1.write('fake_video_data_1')
        video_file2.write('fake_video_data_2')
        video_file1.rewind
        video_file2.rewind

        expect do
          embeddings.send(
            :render_embedding_payload,
            'Test multimodal input',
            model: 'multimodalembedding',
            with: [video_file1, video_file2]
          )
        end.to raise_error(ArgumentError, /This model only supports one video at a time/)
        video_file1.close
        video_file1.unlink
        video_file2.close
        video_file2.unlink
      end

      it 'renders payload wtih dimensions parameter' do
        payload = embeddings.send(
          :render_embedding_payload,
          'Hello!',
          model: 'multimodalembedding',
          dimensions: 512
        )
        expect(payload[:parameters]).to eq({ dimension: 512 })
      end
    end
  end

  describe '#categorize_files' do
    it 'categorizes image files correctly' do
      files = embeddings.send(:categorize_files, ['image.jpg', 'photo.png'])
      expect(files[:image].length).to eq(2)
      expect(files[:video].length).to eq(0)
    end

    it 'categorizes video files correctly' do
      files = embeddings.send(:categorize_files, ['video.mp4', 'movie.mov'])
      expect(files[:image].length).to eq(0)
      expect(files[:video].length).to eq(2)
    end

    it 'categorizes mixed files correctly' do
      files = embeddings.send(:categorize_files, ['image.jpg', 'video.mp4'])
      expect(files[:image].length).to eq(1)
      expect(files[:video].length).to eq(1)
    end

    it 'raises error for unsupported file types' do
      expect do
        embeddings.send(:categorize_files, ['document.pdf'])
      end.to raise_error(ArgumentError, /Unsupported file type/)
    end
  end

  describe '#detect_file_type' do
    it 'detects image formats' do
      expect(embeddings.send(:detect_file_type, 'photo.jpg')).to eq(:image)
      expect(embeddings.send(:detect_file_type, 'image.png')).to eq(:image)
      expect(embeddings.send(:detect_file_type, 'pic.gif')).to eq(:image)
    end

    it 'detects video formats' do
      expect(embeddings.send(:detect_file_type, 'video.mp4')).to eq(:video)
      expect(embeddings.send(:detect_file_type, 'movie.mov')).to eq(:video)
      expect(embeddings.send(:detect_file_type, 'clip.webm')).to eq(:video)
    end

    it 'handles file objects with path method' do
      file = double('file', path: 'image.jpg') # rubocop:disable RSpec/VerifiedDoubles
      expect(embeddings.send(:detect_file_type, file)).to eq(:image)
    end

    it 'returns unknown for unsupported types' do
      expect(embeddings.send(:detect_file_type, 'doc.pdf')).to eq(:unknown)
    end
  end

  describe '#validate_multimodal_inputs' do
    it 'allows single image' do
      files = { image: ['image.jpg'], video: [] }
      expect { embeddings.send(:validate_multimodal_inputs, files) }.not_to raise_error
    end

    it 'allows single video' do
      files = { image: [], video: ['video.mp4'] }
      expect { embeddings.send(:validate_multimodal_inputs, files) }.not_to raise_error
    end

    it 'raises error for multiple images' do
      files = { image: ['img1.jpg', 'img2.jpg'], video: [] }
      expect do
        embeddings.send(:validate_multimodal_inputs, files)
      end.to raise_error(ArgumentError, 'This model only supports one image at a time.')
    end

    it 'raises error for multiple videos' do
      files = { image: [], video: ['vid1.mp4', 'vid2.mp4'] }
      expect do
        embeddings.send(:validate_multimodal_inputs, files)
      end.to raise_error(ArgumentError, 'This model only supports one video at a time.')
    end
  end

  describe '#parse_embedding_response' do
    context 'with text only embeddings' do
      it 'parses text only embedding response' do
        embedding_response = instance_double(
          Faraday::Response, body: {
            'predictions' => [
              'embeddings' => {
                'statistics' => {
                  'truncated' => false,
                  'token_count' => 6
                },
                'values' => ['...']
              }
            ]
          }
        )
        embedding = embeddings.send(
          :parse_embedding_response,
          embedding_response,
          model: 'gemini-embedding-001',
          text: 'Hello!'
        )
        expect(embedding.vectors).to eq(['...'])
        expect(embedding.model).to eq('gemini-embedding-001')
      end

      it 'parses batch text embedding response' do
        embedding_response = instance_double(
          Faraday::Response, body: {
            'predictions' => [
              {
                'embeddings' => {
                  'statistics' => {
                    'token_count' => 8,
                    'truncated' => false
                  },
                  'values' => ['0.1,....']
                }
              },
              {
                'embeddings' => {
                  'statistics' => {
                    'token_count' => 3,
                    'truncated' => false
                  },
                  'values' => ['0.2,....']
                }
              }
            ]
          }
        )
        embedding = embeddings.send(
          :parse_embedding_response,
          embedding_response,
          model: 'text-embedding-004',
          text: ['Hello!', 'Hi there!']
        )
        expect(embedding.vectors).to eq([['0.1,....'], ['0.2,....']])
        expect(embedding.model).to eq('text-embedding-004')
      end
    end

    context 'with multimodal embeddings' do
      it 'parses multimodal embedding response' do
        embedding_response = instance_double(
          Faraday::Response, body: {
            'predictions' => [
              {
                'textEmbedding' => ['0.1,....'],
                'imageEmbedding' => ['0.2,....'],
                'videoEmbeddings' => ['0.3,....']
              }
            ]
          }
        )
        embedding = embeddings.send(
          :parse_embedding_response,
          embedding_response,
          model: 'multimodalembedding',
          text: 'Multimodal input'
        )
        expect(embedding.vectors).to eq(
          {
            text: ['0.1,....'],
            image: ['0.2,....'],
            video: ['0.3,....']
          }
        )
        expect(embedding.model).to eq('multimodalembedding')
      end
    end
  end
end
