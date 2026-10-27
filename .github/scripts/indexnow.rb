#!/usr/bin/env ruby
# frozen_string_literal: true

# IndexNow for a static site, in two steps around a deploy.
#
#   ruby indexnow.rb plan SITE_DIR PLAN_FILE       # static site, before the deploy
#   ruby indexnow.rb snapshot HOST KEY PLAN_FILE   # server-rendered app, before the deploy
#   ruby indexnow.rb submit PLAN_FILE              # after the deploy
#
# `plan` reads the freshly built SITE_DIR: the key file at its root (a
# 32-character hex name whose content is the same key), and sitemap.xml
# (a sitemap index is followed into its child sitemaps). It compares that
# sitemap with the one still live on the site and keeps the URLs that are
# new or whose <lastmod> changed. When the live site does not serve the key
# yet, it is the first run, and every sitemap URL is kept.
#
# `snapshot` is for a site whose sitemap only exists once deployed (a Rails
# app, say): it records the live sitemap before the deploy, and `submit`
# compares it with the live sitemap after the deploy.
#
# `submit` waits until the deploy is live (the key file answers and the live
# sitemap matches the one planned), then posts the URLs to
# https://api.indexnow.org/indexnow, which shares them with Bing, Yandex,
# Seznam, Naver and the other IndexNow engines.
#
# Standard library only, so it runs on a stock CI runner without Bundler.
# Override the endpoint with INDEXNOW_ENDPOINT; set INDEXNOW_DRY_RUN=1 to
# print the request without sending it.

require 'digest'
require 'json'
require 'net/http'
require 'uri'

module IndexNow
  ENDPOINT = ENV.fetch('INDEXNOW_ENDPOINT', 'https://api.indexnow.org/indexnow')
  KEY_FILE = /\A[0-9a-f]{32}\.txt\z/
  BATCH = 10_000
  WAIT_SECONDS = Integer(ENV.fetch('INDEXNOW_WAIT_SECONDS', '600'))

  class Error < StandardError; end

  module_function

  def plan(site_dir, plan_file)
    key = find_key(site_dir)
    built = read_sitemap(File.join(site_dir, 'sitemap.xml')) { |url| local_child(site_dir, url) }
    raise Error, "#{site_dir}/sitemap.xml lists no URLs" if built.empty?

    host = URI(built.keys.first).host
    built.select! { |url, _| URI(url).host == host }
    key_location = "https://#{host}/#{key}.txt"

    first_run = fetch(key_location)&.strip != key
    live = first_run ? {} : live_sitemap(host)
    urls = built.reject { |url, lastmod| live.key?(url) && live[url] == lastmod }.keys

    plan = {
      'host' => host, 'key' => key, 'keyLocation' => key_location,
      'sitemapDigest' => Digest::SHA256.hexdigest(File.read(File.join(site_dir, 'sitemap.xml'))),
      'firstRun' => first_run, 'urlList' => urls
    }
    File.write(plan_file, JSON.pretty_generate(plan))
    puts "IndexNow: #{urls.size} of #{built.size} URLs to submit for #{host}#{' (first run)' if first_run}"
  end

  def snapshot(host, key, plan_file)
    raise Error, "#{key.inspect} is not a 32-character hex IndexNow key" unless "#{key}.txt".match?(KEY_FILE)

    key_location = "https://#{host}/#{key}.txt"
    first_run = fetch(key_location)&.strip != key
    plan = {
      'host' => host, 'key' => key, 'keyLocation' => key_location, 'firstRun' => first_run,
      'before' => first_run ? {} : live_sitemap(host)
    }
    File.write(plan_file, JSON.pretty_generate(plan))
    puts "IndexNow: recorded #{plan['before'].size} live sitemap URLs for #{host}#{' (first run)' if first_run}"
  end

  def submit(plan_file)
    plan = JSON.parse(File.read(plan_file))
    if plan.key?('before')
      wait_until_live(plan)
      after = live_sitemap(plan['host']).select { |url, _| URI(url).host == plan['host'] }
      raise Error, "https://#{plan['host']}/sitemap.xml lists no URLs after the deploy" if after.empty?

      before = plan['before']
      plan['urlList'] = after.reject { |url, lastmod| before.key?(url) && before[url] == lastmod }.keys
      puts "IndexNow: #{plan['urlList'].size} of #{after.size} URLs to submit for #{plan['host']}"
    end
    urls = plan.fetch('urlList')
    if urls.empty?
      puts 'IndexNow: nothing changed, nothing to submit'
      return
    end

    wait_until_live(plan)
    urls.each_slice(BATCH) do |batch|
      body = { 'host' => plan['host'], 'key' => plan['key'], 'keyLocation' => plan['keyLocation'],
               'urlList' => batch }
      if ENV['INDEXNOW_DRY_RUN'] == '1'
        puts JSON.pretty_generate(body)
        next
      end
      post(body)
    end
  end

  def find_key(site_dir)
    keys = Dir.children(site_dir).grep(KEY_FILE).select do |name|
      File.read(File.join(site_dir, name)).strip == File.basename(name, '.txt')
    end
    raise Error, "#{site_dir} has no IndexNow key file (<key>.txt containing the key)" if keys.empty?
    raise Error, "#{site_dir} has more than one IndexNow key file: #{keys.join(', ')}" if keys.size > 1

    File.basename(keys.first, '.txt')
  end

  # Returns { url => lastmod or nil }, following sitemap indexes through the
  # block, which turns a child sitemap URL into its XML (or nil).
  def read_sitemap(source, &child)
    xml = source.is_a?(String) && File.file?(source) ? File.read(source) : source.to_s
    parse(xml, &child)
  end

  def parse(xml, depth = 0, &child)
    entries = {}
    if xml.include?('<sitemapindex')
      return entries if depth > 2

      blocks(xml, 'sitemap').each do |block|
        loc = text(block, 'loc') or next
        nested = yield(loc)
        entries.merge!(parse(nested, depth + 1, &child)) if nested
      end
    else
      blocks(xml, 'url').each do |block|
        loc = text(block, 'loc') or next
        entries[loc] = text(block, 'lastmod')
      end
    end
    entries
  end

  def blocks(xml, tag)
    xml.scan(%r{<#{tag}\b[^>]*>(.*?)</#{tag}>}m).flatten
  end

  def text(block, tag)
    value = block[%r{<#{tag}\b[^>]*>(.*?)</#{tag}>}m, 1]&.strip
    return nil if value.nil? || value.empty?

    value.gsub('&amp;', '&').gsub('&lt;', '<').gsub('&gt;', '>').gsub('&quot;', '"').gsub('&apos;', "'")
  end

  def local_child(site_dir, url)
    path = File.join(site_dir, URI(url).path)
    File.file?(path) ? File.read(path) : nil
  end

  def live_sitemap(host)
    xml = fetch("https://#{host}/sitemap.xml")
    return {} unless xml

    parse(xml) { |url| fetch(url) }
  end

  def wait_until_live(plan)
    deadline = Time.now + WAIT_SECONDS
    sitemap_url = "https://#{plan['host']}/sitemap.xml"
    loop do
      key_live = fetch(plan['keyLocation'])&.strip == plan['key']
      sitemap_live = true
      if plan['sitemapDigest']
        sitemap = fetch(sitemap_url)
        sitemap_live = sitemap && Digest::SHA256.hexdigest(sitemap) == plan['sitemapDigest']
      end
      return if key_live && sitemap_live

      if Time.now > deadline
        raise Error, "#{plan['keyLocation']} does not serve the key after #{WAIT_SECONDS}s" unless key_live

        warn "IndexNow: the live sitemap still differs from the build after #{WAIT_SECONDS}s; submitting anyway"
        return
      end
      sleep 10
    end
  end

  def fetch(url, redirects = 3)
    uri = URI(url)
    uri.query = [uri.query, "indexnow=#{Time.now.to_i}"].compact.join('&')
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 10,
                                                   read_timeout: 20) do |http|
      http.get(uri.request_uri, 'User-Agent' => 'indexnow.rb', 'Cache-Control' => 'no-cache')
    end
    case response
    when Net::HTTPSuccess then response.body.to_s.dup.force_encoding('UTF-8')
    when Net::HTTPRedirection
      redirects.positive? ? fetch(URI.join(url, response['location']).to_s, redirects - 1) : nil
    end
  rescue SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError
    nil
  end

  def post(body)
    uri = URI(ENDPOINT)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 10,
                                                   read_timeout: 30) do |http|
      http.post(uri.request_uri, JSON.generate(body), 'Content-Type' => 'application/json; charset=utf-8')
    end
    case response.code
    when '200', '202'
      puts "IndexNow: submitted #{body['urlList'].size} URLs for #{body['host']} (HTTP #{response.code})"
    else
      raise Error, "IndexNow rejected #{body['urlList'].size} URLs for #{body['host']}: " \
                   "HTTP #{response.code} #{response.body.to_s[0, 300]}"
    end
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    case ARGV
    in ['plan', site_dir, plan_file] then IndexNow.plan(site_dir, plan_file)
    in ['snapshot', host, key, plan_file] then IndexNow.snapshot(host, key, plan_file)
    in ['submit', plan_file] then IndexNow.submit(plan_file)
    else
      warn "usage: #{$PROGRAM_NAME} plan SITE_DIR PLAN_FILE | snapshot HOST KEY PLAN_FILE | submit PLAN_FILE"
      exit 64
    end
  rescue IndexNow::Error => e
    warn "IndexNow: #{e.message}"
    exit 1
  end
end
