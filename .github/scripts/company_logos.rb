#!/usr/bin/env ruby
# frozen_string_literal: true

# Adds the logos of companies that said yes in the usage survey to the
# homepage, for a person to review in a pull request. Prints the names it
# added, so nothing else from a reply may reach the job's public log.

require 'digest'
require 'json'
require 'net/http'
require 'rexml/document'
require 'uri'

# Turns the survey's replies into new homepage logos.
class CompanyLogos
  FORM = '3Na02p'
  COMPANY = 'Company Name'
  CONSENT = 'Can we feature your company as a RubyLLM user?'
  LOGO = 'Company Logo (Vector graphics preferred, otherwise PNG)'
  WITH_LOGO = 'Yes, with logo'
  MAX_BYTES = 1_000_000
  EXTENSIONS = { 'image/svg+xml' => 'svg', 'image/png' => 'png', 'image/jpeg' => 'jpg' }.freeze
  SIGNATURES = { 'png' => "\x89PNG".b, 'jpg' => "\xFF\xD8\xFF".b }.freeze
  ACTIVE_SVG_ELEMENTS = %w[script foreignobject iframe embed object use].freeze
  EXTERNAL_CSS = /\\|@import|url\(\s*['"]?\s*(?!#)/i
  LEGAL_SUFFIX = /[\s,.]+(?:pte|ltd|llc|inc|gmbh|ag|as|bv|sl|srl|co|corp|limited)\b\.?/
  PLACEHOLDERS = %w[none na tbd freelance].freeze

  def initialize(root:, token:)
    @root = root
    @token = token
  end

  def run
    additions = new_companies.filter_map { |company| add(company) }
    additions.each { |name| puts name }
  end

  # The latest reply speaks for a company, so one that withdrew stays off.
  def self.new_companies(replies, known:, skipped:)
    latest = replies.sort_by { |reply| reply[:submitted_at] }.group_by { |reply| key(reply[:company]) }
    latest.filter_map do |company_key, company_replies|
      reply = company_replies.last
      next if company_key.empty? || PLACEHOLDERS.include?(company_key)
      next if (known + skipped).map { |name| key(name) }.include?(company_key)
      next unless reply[:consent] == WITH_LOGO && reply[:logo]

      reply.merge(company: display_name(reply[:company]))
    end
  end

  def self.key(name)
    display_name(name).downcase.gsub(LEGAL_SUFFIX, '').gsub(/[^a-z0-9]/, '')
  end

  def self.display_name(name)
    name.to_s.sub(/\s*\(.*\z/, '').gsub(/[^[:alnum:] .,&'+-]/, '').strip
  end

  def self.safe_logo?(bytes, extension)
    return false if bytes.empty? || bytes.bytesize > MAX_BYTES
    return bytes.start_with?(SIGNATURES.fetch(extension)) unless extension == 'svg'

    text = bytes.dup.force_encoding('UTF-8')
    text.valid_encoding? && safe_svg?(REXML::Document.new(text))
  rescue REXML::ParseException
    false
  end

  # Names are compared without their prefix, so <x:script> counts as a script.
  def self.safe_svg?(document)
    return false unless document.root&.name&.casecmp?('svg')
    return false if document.doctype&.children&.any? || document.children.grep(REXML::Instruction).any?

    REXML::XPath.match(document, '//*').all? { |element| safe_svg_element?(element) }
  end

  def self.safe_svg_element?(element)
    return false if ACTIVE_SVG_ELEMENTS.include?(element.name.downcase)
    return false if element.name.casecmp?('style') && element.texts.map(&:value).join.match?(EXTERNAL_CSS)

    element.attributes.each_attribute.none? { |attribute| unsafe_svg_attribute?(attribute) }
  end

  def self.unsafe_svg_attribute?(attribute)
    name = attribute.name.downcase
    value = attribute.value.strip
    return true if name.start_with?('on') || value.match?(EXTERNAL_CSS)
    return value.downcase.end_with?('href') if name == 'attributename'

    name == 'href' && !value.start_with?('#')
  end

  private

  def new_companies
    self.class.new_companies(replies, known: names_in(logos_path) + names_in(all_logos_path), skipped: names_in(skipped_path))
  end

  def add(company)
    extension = EXTENSIONS[company[:logo]['mimeType']]
    return unless extension

    bytes = download(company[:logo]['url'])
    return unless bytes && self.class.safe_logo?(bytes, extension)

    slug = company[:company].downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-|-\z/, '')
    path = File.join(@root, 'docs/assets/images/companies/survey-2026', "#{slug}.#{extension}")
    return if File.exist?(path) || existing_logo?(bytes)

    File.binwrite(path, bytes)
    File.write(logos_path, entry(company[:company], "#{slug}.#{extension}"), mode: 'a')
    company[:company]
  end

  # A missing upload must not hold back the other companies, and the error
  # stays out of the log because it can carry the upload's URL.
  def download(url)
    get(URI(url))
  rescue StandardError
    nil
  end

  def existing_logo?(bytes)
    digest = Digest::SHA256.digest(bytes)
    Dir[File.join(@root, 'docs/assets/images/companies/survey-2026/*')].any? do |file|
      Digest::SHA256.file(file).digest == digest
    end
  end

  def entry(name, file)
    %(- name: #{name.to_json}\n  src: "/assets/images/companies/survey-2026/#{file}"\n)
  end

  def replies
    pages.flat_map do |page|
      page['submissions'].map { |submission| reply(submission, page['questions']) }
    end
  end

  def reply(submission, questions)
    answers = submission['responses'].to_h { |response| [response['questionId'], response['answer']] }
    answer = ->(title) { answers[questions.find { |question| question['title'] == title }&.dig('id')] }
    { submitted_at: submission['submittedAt'], company: answer[COMPANY], consent: Array(answer[CONSENT]).first,
      logo: Array(answer[LOGO]).first }
  end

  def pages
    Enumerator.new do |pages|
      number = 1
      loop do
        page = JSON.parse(get(URI("https://api.tally.so/forms/#{FORM}/submissions?page=#{number}&limit=100"), auth: true))
        pages << page
        break unless page['hasMore']

        number += 1
      end
    end
  end

  def get(uri, auth: false, redirects: 3)
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{@token}" if auth
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
    return get(URI(response['location']), redirects: redirects - 1) if response.is_a?(Net::HTTPRedirection) && redirects.positive?

    response.value
    response.body
  end

  def names_in(path)
    File.exist?(path) ? File.read(path).scan(/^\s*-\s*(?:name:\s*)?"?([^"\n]+)"?$/).flatten : []
  end

  def logos_path = File.join(@root, 'docs/_data/company_logos_featured.yml')
  def all_logos_path = File.join(@root, 'docs/_data/company_logos.yml')
  def skipped_path = File.join(@root, 'docs/_data/company_logos_skipped.yml')
end

CompanyLogos.new(root: File.expand_path('../..', __dir__), token: ENV.fetch('TALLY_API_KEY')).run if $PROGRAM_NAME == __FILE__
