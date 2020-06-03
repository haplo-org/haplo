# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class KColourEvaluator

  # Users define methods on this class to perform action requiring colour evaluation

  # Convert a colour expression to a Ruby expression for use in templates and defining methods
  def self.expression_to_ruby(expression)
    expression = expression.dup
    # Need to turn the hex values into integers?
    expression.gsub!(/#([0-9A-Fa-f])([0-9A-Fa-f])([0-9A-Fa-f])\b/, '0x\\1\\1\\2\\2\\3\\3')
    expression.gsub!(/#([0-9A-Fa-f]+)\b/, '0x\\1')
    # Turn component names shortcut into function call
    expression.gsub!(/\:(\w+)\.(\w+)/) do
      "cvalue(:#{$1},:#{$2.downcase})"
    end
    %Q!colour_out(#{expression})!
  end

  # ----------------------------------------------------------------------------------
  def initialize(dynamic_image_serial)
    @dynamic_image_serial = dynamic_image_serial
    @named_colours = Hash.new
  end
  def set_named_colour(name, value)
    if value.class == String
      if value =~ /\A#?([0-9A-Fa-f])([0-9A-Fa-f])([0-9A-Fa-f])\z/
        value = "#{$1}#{$1}#{$2}#{$2}#{$3}#{$3}".to_i(16)
      elsif value =~ /\A#?([0-9A-Fa-f]+)\z/
        value = $1.to_i(16)
      elsif value == ''
        value = 0
      else
        raise "Bad value"
      end
    end
    @named_colours[name] = value
  end
  def colour_components(c)
    c = @named_colours[c] if c.class == Symbol
    raise "No colour" if c.class != Integer
    [(c >> 16) & 0xff, (c >> 8) & 0xff, c & 0xff]
  end
  def components_colour(c)
    r, g, b = c
    r = 0 if r < 0
    g = 0 if g < 0
    b = 0 if b < 0
    r = 255 if r > 255
    g = 255 if g > 255
    b = 255 if g > 255
    (r << 16) | (g << 8) | b
  end
  def rgb_to_hsv(c)
    components = c.map { |i| i.to_f / 255.0 }
    min = components.min
    max = components.max
    r,g,b = components
    # hue
    hue = 0
    if max == min
      hue = 0
    elsif max == r && g >= b
      hue = 6000 * ((g - b) / (max - min)) + 0
    elsif max == r && g < b
      hue = 6000 * ((g - b) / (max - min)) + 36000
    elsif max == g
      hue = 6000 * ((b - r) / (max - min)) + 12000
    elsif max == b
      hue = 6000 * ((r - g) / (max - min)) + 24000
    end
    hue = 0 if hue < 0 || hue >= 36000
    # saturation
    saturation = (((max == 0) ? 0 : (1.0 - (min / max))) * 10000).to_i
    saturation = 0 if saturation < 0
    saturation = 10000 if saturation > 10000
    # value
    value = (max * 10000.0).to_i
    value = 0 if value < 0
    value = 10000 if value > 10000
    # return
    [hue, saturation, value]
  end
  def hsv_to_rgb(c)
    hue, saturation, value = c
    if saturation == 0
      n = ((value.to_f * 255) / 10000).round
      [n, n, n]
    else
      h = hue.to_f / 36000.0
      s = saturation.to_f / 10000.0
      v = value.to_f / 10000.0

      hx = hue.to_f / 6000.0
      hx = 0 if hx >= 6.0

      i = hx.floor
      f = hx - i
      x = v * (1 - s)
      y = v * (1 - s * f)
      z = v * (1 - s * (1 - f))

      result = case i
      when 0; [v, z, x]
      when 1; [y, v, x]
      when 2; [x, v, z]
      when 3; [x, y, v]
      when 4; [z, x, v]
      else;   [v, x, y]
      end
      result.map! {|i| (i * 255.0).round }
      result.map! {|i| (i > 255) ? 255 : i}
      result.map! {|i| (i < 0) ? 0 : i}
      result
    end
  end

  # Wrapper functions
  HEX_FORMAT = '#%06x'
  def colour_hex(c)
    sprintf(HEX_FORMAT, c)
  end
  def colour_out(r)
    r = @named_colours[r] if r.class == Symbol
    raise "Bad colour evaluator result" if r.class != Integer
    r
  end

  # Helper for dynamic images
  def dynamic_image_serial
    @dynamic_image_serial
  end

  # Operators for expressions
  def mix(*a)
    num = a.length / 2
    raise "No args" if num <= 0
    c = [0,0,0]
    0.upto(num - 1) do |i|
      e = colour_components(a[i*2])
      p = a[(i*2)+1]
      0.upto(2) do |x|
        c[x] += (e[x] * p) / 100
      end
    end
    components_colour(c)
  end
  def adjust(col,sat,val)
    e = colour_components(col)
    hsv = rgb_to_hsv(e)
    hsv[1] += sat * 100
    hsv[2] += val * 100
    1.upto(2) do |i|
      hsv[i] = 0 if hsv[i] < 0
      hsv[i] = 10000 if hsv[i] > 10000
    end
    components_colour(hsv_to_rgb(hsv))
  end
  def max_contrast(col,*choices)
    hsv = rgb_to_hsv(colour_components(col))
    choices = [0,0xffffff] if choices.length == 0   # use black and white if nothing specified
    r = 0xff0000
    dist = nil
    choices.each do |ch|
      chsv = rgb_to_hsv(colour_components(ch))
      d1 = hsv[1] - chsv[1]
      d2 = hsv[2] - chsv[2]
      d = (d1 * d1) + (d2 * d2)
      if dist == nil || dist < d
        r = ch
        dist = d
      end
    end
    r
  end
  CVALUE_RGB = {:r => 0, :g => 1, :b => 2}
  CVALUE_HSV = {:h => 0, :s => 1, :v => 2}
  def cvalue(col,component)
    if CVALUE_HSV.has_key?(component)
      n = rgb_to_hsv(colour_components(col))[CVALUE_HSV[component]]
      (n / 100.0).round # round up
    elsif CVALUE_RGB.has_key?(component)
      colour_components(col)[CVALUE_RGB[component]]
    else
      raise "No such component #{component}"
    end
  end
  def set_sv(col,s,v)
    hsv = rgb_to_hsv(colour_components(col))
    hsv[1] = s * 100 if s != nil
    hsv[2] = v * 100 if v != nil
    components_colour(hsv_to_rgb(hsv))
  end
  def set_s(col,s)
    set_sv(col,s,nil)
  end
  def set_v(col,v)
    set_sv(col,nil,v)
  end

  def _border_tone(col)
    hsv = rgb_to_hsv(colour_components(col))
    if hsv[2] < 2500
      :dark
    elsif hsv[1] < 1000 && hsv[2] > 7000
      :light
    else
      :normal
    end
  end
  def border_light(col)
    if _border_tone(col) == :light
      mix(col, 95, 0x000000, 5)
    else
      mix(col, 50, 0xffffff, 50)
    end
  end
  def border_dark(col)
    if _border_tone(col) == :dark
      mix(col, 80, 0xffffff, 20)
    else
      mix(col, 70, 0x000000, 30)
    end
  end
end


