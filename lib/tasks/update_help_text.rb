# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


require 'net/http'
require 'rubygems'
gem 'RedCloth'
require 'RedCloth'
require 'fileutils'

begin

  PAGES_DIR = 'doc/help-text'

  pages = Hash.new
  Dir.entries(PAGES_DIR).each do |filename|
    pathname = "#{PAGES_DIR}/#{filename}"

    if filename =~ /\.textile$/ && filename != 'HomePage.textile'
      # Make the human readable pathname
      name = filename.gsub(/\.textile$/,'').gsub('_',' ')
      File.open(pathname) { |f| pages[name] = f.read }
    end
  end

  # Now process them
  def process_text(pages, start_pages)
    html = ''
    pages_done = Array.new
    url_data = Array.new
    next_id = 0
    page_ids = Hash.new
    start_pages.each do |name|
      page_ids[name] = next_id
      next_id += 1
    end
    # Process pages
    pages_todo = start_pages.dup
    while ! pages_todo.empty?
      this_page = pages_todo.shift
      unless pages_done.include?(this_page)
        this_id = page_ids[this_page]
        raise "no id" if this_id == nil

        # Header
        html << %Q!<div id="p#{this_id}" style="display:none">\n!

        # Get the FOR links out of the text
        page = pages[this_page].gsub(/^FOR:\s+(.+?)$/) do |m|
          url_data << [$1.strip, this_id, this_page]
          ''
        end

        # Handle text marked <nowiki>
        nowiki = Hash.new
        page.gsub!(/\<nowiki\>(.*?)\<\/nowiki\>/) do |m|
          marker = "NOWIKI-#{nowiki.length}-NOWIKI"
          nowiki[marker] = $1
          marker
        end

        processed = RedCloth.new(page, [:no_span_caps]).to_html.gsub(/\[\[([^\]]+)\]\]/) do |match|
          link_to_name = $1
          unless pages.has_key?(link_to_name)
            link_to_name
          else
            # Make a link to the page
            link_to_id = page_ids[link_to_name]
            if link_to_id == nil
              # Allocate ID
              link_to_id = next_id
              next_id += 1
              page_ids[link_to_name] = link_to_id
              # Add to list for processing
              pages_todo << link_to_name
            end
            %Q!<a href="#" data-page="#{link_to_id}">#{link_to_name}</a>!
          end
        end .gsub(/\n+/,"\n").gsub('<br />','<br>').gsub(/(NOWIKI\-\d+\-NOWIKI)/) { |m| nowiki[$1] }

        # Add in access key insert point
        processed.gsub!('=ACCESSKEY=', '<%= @browser_accesskey %>')

        puts "WARNING: #{this_page} doesn't have any text" unless processed =~ /\S/

        html << processed

        # Footer
        html << "\n</div>\n\n"

        pages_done << this_page
      end
    end

    # Check URLs
    seen_urls = Hash.new
    url_data.each do |url,page_id,page_name|
      if seen_urls[url]
        puts "DUPLICATE: #{url} in #{page_name}, #{seen_urls[url]}"
      end
      seen_urls[url] = page_name
      if url =~ /\d/ || !(url =~ /^\//) || url =~ /\/$/
        puts "#{url} -> #{page_name.gsub(' ','+')}"
      end
    end

    # Sort URLs with the longest first, so they match correctly
    url_data.sort! do |a,b|
      a_len = a.first.length
      b_len = b.first.length
      (a_len == b_len) ? b.first <=> a.first : b_len <=> a_len
    end

    # Turn URL data into text
    url_data_as_text = url_data.map do |url,page_id,page_name|
      %Q!['#{url}',#{page_id}]!
    end .join(",")

    [html, pages_done, url_data, url_data_as_text]
  end

  # Admin pages
  admin_html, admin_pages, admin_url_data, admin_urls = process_text(pages, ["Admin"])
  File.open("app/views/system/_help_text.html.erb","w") { |f| f.write(admin_html) }
  File.open("app/views/system/_help_mapping.html.erb","w") { |f| f.write(admin_urls) }

  # User pages
  user_html, user_pages, user_url_data, user_urls = process_text(pages, ["User", "Glossary"])
  File.open("app/views/help/_help_text.html.erb","w") { |f| f.write(user_html) }
  File.open("app/views/help/_help_mapping.html.erb","w") { |f| f.write(user_urls) }
end

