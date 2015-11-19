#!/usr/bin/env ruby
#/ Usage: <progname> [options]...
#/ How does this script make my life easier?
# ** Tip: use #/ lines to define the --help usage message.
$stderr.sync = true
require 'optparse'
require 'uri'
require 'open-uri'
require 'net/http'
require 'json'
require 'awesome_print'
require 'nokogiri'

trap 'INT' do
  puts 'Goodbye cruel world'
  exit 0
end

input = 'spotify.txt'

file = __FILE__
ARGV.options do |opts|
  opts.on('-i', '--input=val', String)     { |val| input = val }
  opts.parse!
end

def netease_search(query)
  url = URI("http://music.163.com/api/search/pc?type=1&s=#{query}&limit=5&offset=0")
  http = Net::HTTP.new(url.host, url.port)
  request = Net::HTTP::Post.new(url)
  request['Referer'] = 'http://music.163.com/'
  request['Cookie'] = 'appver=1.5.0.75771;'
  response = http.request(request)
  JSON.parse(response.read_body)
end

def http_download_uri(uri, filename)
  puts 'Starting HTTP download for: ' + uri.to_s
  http_object = Net::HTTP.new(uri.host, uri.port)
  http_object.use_ssl = true if uri.scheme == 'https'
  begin
    http_object.start do |http|
      request = Net::HTTP::Get.new uri.request_uri
      http.read_timeout = 500
      http.request request do |response|
        open filename, 'w' do |io|
          response.read_body do |chunk|
            io.write chunk
          end
        end
      end
    end

  rescue Exception => e
    puts "=> Exception: '#{e}'. Skipping download."
    return
  end
  puts 'Stored download as ' + filename
end

failed = []
open(input) do |file|
  file.each_line do |line|
    puts line
    str = Nokogiri::HTML(open(line.chomp)).title
    puts str
    name = str.scan(/^(.*?), a song by (.*?) on Spotify$/).first.join(' - ')
    begin
      url = netease_search(name).fetch('result').fetch('songs').first.fetch('mp3Url')
    rescue
      failed << str
      next
    end

    http_download_uri(URI.parse(url), "#{name}.mp3")
  end
end

ap failed
