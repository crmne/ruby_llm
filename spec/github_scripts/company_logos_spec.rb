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

  it 'accepts an SVG that links to its own gradient' do
    svg = '<svg><linearGradient id="a"/><linearGradient href="#a"/><![CDATA[<script>]]></svg>'

    expect(described_class.safe_logo?(svg, 'svg')).to be(true)
  end

  it 'accepts what ordinary exports contain' do
    doctype = '<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 20010904//EN" "http://www.w3.org/x.dtd">'

    expect(described_class.safe_logo?("#{doctype}<svg/>", 'svg')).to be(true)
    expect(described_class.safe_logo?('<svg><animate attributeName="opacity"/></svg>', 'svg')).to be(true)
    expect(described_class.safe_logo?('<svg><style>.a { fill: url(#b) }</style><path fill="url(#b)"/></svg>',
                                      'svg')).to be(true)
  end

  it 'moves past a logo that fails to download' do
    logos = described_class.new(root: Dir.pwd, token: 'x')
    allow(Net::HTTP).to receive(:start).and_raise(SocketError)

    expect(logos.send(:download, 'https://x.test/logo.svg')).to be_nil
  end

  it 'refuses active SVG content, forged images, and oversized files' do
    ['<svg><script>x</script></svg>', '<svg onload="x"/>', '<svg><a href="https://x.test"/></svg>',
     '<svg xmlns:x="http://www.w3.org/2000/svg"><x:script>x</x:script></svg>',
     '<svg xmlns:l="http://www.w3.org/1999/xlink"><a l:href="https://x.test"/></svg>',
     '<svg><set attributeName="href" to="https://x.test"/></svg>',
     '<svg><animate attributeName="xlink:href" to="https://x.test"/></svg>',
     '<!DOCTYPE svg [<!ENTITY x "y">]><svg>&x;</svg>', '<?xml-stylesheet href="x.css"?><svg/>',
     '<svg><style>@import url(https://x.test/a.css);</style></svg>',
     '<svg><style><![CDATA[rect { fill: url(https://x.test/a.svg#b) }]]></style></svg>',
     '<svg><rect style="fill: url(\'https://x.test/a.svg#b\')"/></svg>',
     '<svg><style>@\\69mport "https://x.test/a.css";</style></svg>',
     '<svg><style>@im<![CDATA[port "https://x.test/a.css";]]></style></svg>',
     '<svg><path></svg>', '<html/>'].each do |svg|
      expect(described_class.safe_logo?(svg, 'svg')).to be(false), svg
    end
    expect(described_class.safe_logo?('<svg/>', 'png')).to be(false)
    expect(described_class.safe_logo?("\x89PNG".b + ('a' * described_class::MAX_BYTES), 'png')).to be(false)
  end
end
