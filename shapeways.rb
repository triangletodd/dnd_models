#!/usr/bin/env ruby
require 'zip'
require 'mechanize'

SW_USER = ENV['SW_USER'] || ARGV[0] 
SW_PASS = ENV['SW_PASS'] || ARGV[1] 
BASE_URL = 'https://www.shapeways.com'

class String
  def to_snake
    self.gsub(/\s*(-|\(updated\))\s*/, '').
    gsub(/\s/, '_').
    downcase
  end
end

module Nokogiri
  module XML
    class Element
      def stl_ids
        self.css('div.grid-view').css('div.product-box').collect do |ele|
          id, title = [ ele.attr('data-spin').strip, ele.attr('title').strip ]
          { id: id, title: title.to_snake }
        end
      end

      def prev_ele
        self.css('div.pagination').css('a').select do |ele|
          ele.attr('data-sw-tracking-link-id') == 'previous'
        end.first
      end

      def next_ele
        self.css('div.pagination').css('a').select do |ele|
          ele.attr('data-sw-tracking-link-id') == 'next'
        end.first
      end
    end
  end
end

@stls = []
@page = "#{BASE_URL}/designer/mz4250/creations"

def download_url_for(id)
  "#{BASE_URL}/product/download/#{id}"
end

def unzip_bytes(zipbytes,dir=Dir.pwd)
  Zip::File.open_buffer(zipbytes) do |zip_file|
    zip_file.each do |file|
      dest_file = File.join(dir, file.name)
      zip_file.extract(file, dest_file) unless File.exist?(dest_file)
    end
  end
end

mech = Mechanize.new do |options| 
  options.follow_meta_refresh = true
end

mech.get(BASE_URL + '/login') do |login_page|
  login_page.form_with(id: 'form1') do |form|
    form.username = SW_USER
    form.password = SW_PASS
  end.submit
end

while true do
  page = mech.get(@page).at('html')
  @stls += page.stl_ids
  break if page.next_ele.nil?
  @page = page.next_ele.attr('href')
end


@stls.each do |stl|
  url = download_url_for stl[:id]
  zipbytes = mech.get(url).body
  Dir.mkdir(stl[:title]) unless Dir.exists?(stl[:title])
  unzip_bytes(zipbytes, stl[:title])
end

