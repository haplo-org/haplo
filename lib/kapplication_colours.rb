# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



module KApplicationColours

    DEFAULT_CUSTOM_COLOURS = '007|00F|F00|333|AUTO|AUTO|AUTO|AUTO|F1E4E4|D00|F1E4F1|909|E4F1E4|090|D4DFEA|009|E5E5F2|66B|EEE5DC|965|E5F2F2|488|DDD|666|FFF|444|AUTO|AUTO|AUTO|F00|9C3|9CF'

    # --------------------------------------------------------------------------
    # Definition of custom colour names and symbols
    #
    CUSTOM_COLOURS = [
      ['Main',                :main],
      ['Secondary',           :secondary],
      ['Highlight',           :highlight],
      ['Heading',             :heading],
      ['Heading line',        :divider_line,    ':main'],
      ['Background 1',        :background0,     'mix(:main,40,#fff,60)'], # for home page banner image backgrounds, etc
      ['Background 2',        :background1,     'mix(:main,40,#fff,60)'],
      ['Background 3',        :background2,     'mix(:main,40,#fff,60)'],
      ['Category 1 light',    :category0_light],
      ['Category 1',          :category0],  # note 1 and 0 indicies
      ['Category 2 light',    :category1_light],
      ['Category 2',          :category1],
      ['Category 3 light',    :category2_light],
      ['Category 3',          :category2],
      ['Category 4 light',    :category3_light],
      ['Category 4',          :category3],
      ['Category 5 light',    :category4_light],
      ['Category 5',          :category4],
      ['Category 6 light',    :category5_light],
      ['Category 6',          :category5],
      ['Category 7 light',    :category6_light],
      ['Category 7',          :category6],
      ['Category 8 light',    :category7_light],
      ['Category 8',          :category7],
      ['Icon 1',              :icon0],
      ['Icon 2',              :icon1],
      ['Icon 3',              :icon2,           ':main'],
      ['Icon 4',              :icon3,           ':secondary'],
      ['Icon 5',              :icon4,           ':highlight'],
      ['Icon 6',              :icon5],
      ['Icon 7',              :icon6],
      ['Icon 8',              :icon7]
    ]

  # Make definitions for colours?
  NAME_TO_INDEX = {}
  CUSTOM_COLOURS.each_with_index do |defn, index|
    NAME_TO_INDEX[defn[1]] = index
    if defn.length > 2
      # Yes - replace with a function definition
      method_name = "__cc_defaults_#{defn[1]}".to_sym
      KColourEvaluator.module_eval("def #{method_name}\n#{KColourEvaluator.expression_to_ruby(defn[2])}\nend", method_name.to_s, -1)
      defn[2] = method_name
    end
  end

  def self.get_colour(name)
    c = KApp.global(:appearance_colours).split('|')
    colour = (c[NAME_TO_INDEX[name] || 0] || '000000').downcase
    if colour.length === 3
      colour = colour.split(//).map { |e| "#{e}#{e}" }.join
    end
    (colour =~ /\A[a-z0-9]{6}\z/) ? colour : '000000'
  end

  # ------------------------------------------------------------------------------------------------------
  # Make a colour evaulator from the globals
  def self.make_colour_evaluator
    e = KColourEvaluator.new(KApp.global(:appearance_update_serial))
    c = KApp.global(:appearance_colours).split('|')
    auto_cols = Array.new
    0.upto(CUSTOM_COLOURS.length - 1) do |i|
      if c[i] == 'AUTO'
        auto_cols << i
      else
        e.set_named_colour(CUSTOM_COLOURS[i][1], c[i])
      end
    end
    # Set auto colours by evaluating the defaults in respect of other colours
    auto_cols.each do |i|
      c = 0xff0000 # error colour
      if CUSTOM_COLOURS[i].length > 2
        # Has a default colour string, which was mapped into a method name above
        c = e.send(CUSTOM_COLOURS[i][2])
      end
      # Slight hack
      e.set_named_colour(CUSTOM_COLOURS[i][1], sprintf("%06x",c))
    end
    e
  end

end

