# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class Setup_AppearanceController < ApplicationController
  include ERB::Util # for html_escape
  policies_required :setup_system, :not_anonymous
  include Setup_AppearanceHelper
  include Application_IconHelper

  _GetAndPost
  def handle_index
    # Note: application colour names come from lib/kapplication_colours.rb
    # Make a hash of colour name to colour and used colour names
    @colour_name_usage = Hash.new
    @colours = Hash.new
    @colour_has_default = Hash.new
    c = KApp.global(:appearance_colours).split('|')
    n = 0
    KApplicationColours::CUSTOM_COLOURS.each do |name,symbol,def_col|
      @colours[symbol] = c[n] if n < c.length
      n += 1
      @colour_name_usage[symbol] = true
      @colour_has_default[symbol] = true if def_col != nil
    end

    if request.post?
      colours_updated = false
      case params['which']
      when 'globals'
        old_css = KApp.global(:appearance_css).gsub(/\s+\z/m,'')  # avoid updating if whitespace / line endings gets appended
        update_appglobal_strings_no_escape(:appearance_header, :appearance_css)
        if KApp.global(:appearance_css).gsub(/\s+\z/m,'') != old_css
          # Invalidate all the cached app dynamic files in framework and browsers
          KDynamicFiles.invalidate_all_cached_files_in_current_app
        end
        redirect_to('/do/setup/appearance/applied')
      when 'colours'
        cols = Array.new
        KApplicationColours::CUSTOM_COLOURS.each do |name,symbol|
          key = symbol.to_s
          v = (params.has_key?(key)) ? params[key].upcase : @colours[symbol]
          if v == 'AUTO'
            cols << v
          else
            cols << v.gsub(/[^0-9A-Z]/,'')
          end
        end
        KApp.set_global(:appearance_colours, cols.join('|'))
        colours_updated = true
      when 'colourset'
        if params['set'] != ''
          KApp.set_global(:appearance_colours, params['set'])
          colours_updated = true
        end
      end
      if colours_updated
        # Invalidate all the cached app dynamic files in framework and browsers
        KDynamicFiles.invalidate_all_cached_files_in_current_app
        # Move on to next page?
        if params.has_key?('apply')
          # Need redirect to reflect the colours in the form which is redisplayed
          redirect_to('/do/setup/appearance')
        else
          redirect_to('/do/setup/appearance/applied')
        end
      end
    end
  end

  def handle_applied
  end

  _GetAndPost
  def handle_webfonts
    @webfont_size = (KApp.global(:appearance_webfont_size) || 0)
    @settings = [
        ["Disabled (fastest initial download)", 0],
        ["Latin characters only (recommended)", 4],
        ["Full character set (slower initial download)", 8]
      ]
    if request.post?
      new_setting = params['size'].to_i
      if new_setting != @webfont_size
        @webfont_size = new_setting
        KApp.set_global(:appearance_webfont_size, new_setting)
        KDynamicFiles.invalidate_all_cached_files_in_current_app
      end
    end
    render :layout => 'management'
  end

  def handle_icon_designer
  end

private
  def update_appglobal_strings_no_escape(*syms)
    syms.each do |sym|
      ag = KApp.global(sym)
      n = params[sym.to_s] # no escaping
      if n != nil && ag != n
        KApp.set_global(sym, n)
      end
    end
  end
end
