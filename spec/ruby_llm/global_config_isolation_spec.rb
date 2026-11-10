# frozen_string_literal: true

require 'spec_helper'

# Many examples set RubyLLM.config directly. A value left behind reaches
# every later example in the same process, such as a retry count that
# makes a rate-limited request run twice, so each example starts on the
# suite's own configuration.
RSpec.describe 'RubyLLM.config between examples', order: :defined do # rubocop:disable RSpec/DescribeClass
  it 'lets an example change the global configuration' do
    RubyLLM.config.max_retries = 5
    RubyLLM.config.request_timeout = 1
    RubyLLM.config.file_converters['text/x-isolation'] = ->(file) { file }

    expect(RubyLLM.config).to have_attributes(max_retries: 5, request_timeout: 1)
  end

  it 'starts the next example on the suite configuration' do
    expect(RubyLLM.config).to have_attributes(max_retries: 0, request_timeout: RubyLLM::Configuration.new.request_timeout)
    expect(RubyLLM.config.file_converters).not_to have_key('text/x-isolation')
  end
end
