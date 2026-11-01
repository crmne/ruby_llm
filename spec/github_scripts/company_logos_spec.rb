# frozen_string_literal: true

require 'spec_helper'
require_relative '../../.github/scripts/company_logos'

RSpec.describe CompanyLogos do
  def reply(company, consent: described_class::WITH_LOGO, logo: { 'url' => 'x' }, at: '2026-01-01')
    { company:, consent:, logo:, submitted_at: at }
  end

  def names(replies, known: [], skipped: [])
    described_class.new_companies(replies, known:, skipped:).map { |company| company[:company] }
  end

  it 'proposes a company that said yes and sent a logo' do
    expect(names([reply('Acme (https://acme.test)')])).to eq(['Acme'])
  end

  it 'leaves out a company without consent, a logo, or a real name' do
    replies = [reply('Quiet', consent: 'No'), reply('Plain', consent: 'Yes, but only company name'),
               reply('Bare', logo: nil), reply('None'), reply('')]

    expect(names(replies)).to be_empty
  end

  it 'lets the latest reply speak for a company' do
    replies = [reply('Acme', at: '2026-01-01'), reply('ACME', consent: 'No', at: '2026-02-01')]

    expect(names(replies)).to be_empty
  end

  it 'matches known and skipped names past their legal suffix' do
    expect(names([reply('Acme PTE LTD'), reply('Beta Inc.')], known: ['Acme'], skipped: ['Beta'])).to be_empty
  end

  it 'accepts a plain SVG and an image with the right signature' do
    expect(described_class.safe_logo?('<svg xmlns="http://www.w3.org/2000/svg"><path d="M0 0"/></svg>',
                                      'svg')).to be(true)
    expect(described_class.safe_logo?("\x89PNG rest".b, 'png')).to be(true)
  end

  it 'refuses active SVG content, forged images, and oversized files' do
    ['<svg><script>x</script></svg>', '<svg onload="x"/>', '<svg><a href="https://x.test"/></svg>'].each do |svg|
      expect(described_class.safe_logo?(svg, 'svg')).to be(false)
    end
    expect(described_class.safe_logo?('<svg/>', 'png')).to be(false)
    expect(described_class.safe_logo?("\x89PNG".b + ('a' * described_class::MAX_BYTES), 'png')).to be(false)
  end
end
