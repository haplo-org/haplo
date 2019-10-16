# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# There is some potentially cultural specific assumptions in this code, regarding the end points of ranges.
# If the range has minute or hour precision, the end point is exactly the time entered. If it's a longer
# precision, the end of the range is extended by the length of the precision.
# If this code is extended to be culturally aware, the contents of the object should be exactly what the
# user entered, but include which culture was used to enter that date.

class KDateTime
  include Java::OrgHaploJsinterfaceApp::AppDateTime

  PRECISION_OPTIONS = [
    ['Century', 'C'],
    ['Decade', 'D'],
    ['Year', 'Y'],
    ['Month', 'M'],
    ['Day', 'd'],
    ['Hour', 'h'],
    ['Minute', 'm']
  ]
  PRECISION_OPTION_TO_NAME = {}
  PRECISION_OPTIONS.each do |n,o|
    n.freeze
    o.freeze
    PRECISION_OPTION_TO_NAME[o] = n
  end
  PRECISION_OPTIONS.freeze
  PRECISION_OPTION_TO_NAME.freeze

  # --------------------------------------------------------------------------------------------------------------

  def k_typecode
    KConstants::T_DATETIME
  end

  # --------------------------------------------------------------------------------------------------------------
  # Construct

  def initialize(start_time, end_time = nil, precision = nil, timezone = nil)
    raise "Bad precision pass to KDateTime" if precision != nil && !PRECISION_OPTION_TO_NAME.has_key?(precision)
    start_time_i = _datetime_to_internal(start_time, precision)
    end_time_i = _datetime_to_internal(end_time, precision)
    raise "No start time passed to KDateTime constructor" if start_time_i == nil
    if end_time_i != nil
      # Swap times?
      if _compare_times(start_time_i, end_time_i) > 0
        t = start_time_i
        start_time_i = end_time_i
        end_time_i = t
      end
      # Check values have same length
      raise "Range passed to KDateTime constructor do not have the same precision" if start_time_i.length != end_time_i.length
      # Store end time
      @e = end_time_i
    end
    # Store start time
    @s = start_time_i
    # Choose precision
    @p = precision || LENGTH_TO_PRECISION[start_time_i.length]
    if timezone != nil
      raise "Bad timezone" unless timezone.kind_of?(String) && TZInfo::Timezone.valid?(timezone)
      @z = timezone
    end
  end

  # --------------------------------------------------------------------------------------------------------------
  # Equality tests

  def ==(other)
    return false if other == nil
    @s == other._s && @e == other._e && @p == other._p && @z == other._z
  end
  def eql?(other)
    return false if other == nil
    @s == other._s && @e == other._e && @p == other._p && @z == other._z
  end
  def _s; @s; end
  def _e; @e; end
  def _p; @p; end
  def _z; @z; end

  # --------------------------------------------------------------------------------------------------------------
  # Access data

  def precision
    @p
  end

  def timezone
    (@z != nil) ? @z.dup : nil
  end

  def keditor_values
    [_internal_to_string(@s), _internal_to_string(@e), @p.dup, (@z != nil) ? @z.dup : '']
  end

  def to_s(timezone = nil)
    _to_formatted(timezone, false)
  end

  def to_html(timezone = nil)
    _to_formatted(timezone, true)
  end

  def range_pg
    _make_range.map { |d| d.strftime(PG_TIMESTAMP_FORMAT) }
  end

  def start_datetime
    _to_gmt(_internal_to_datetime(@s))
  end

  def midpoint_datetime
    range = _make_range # which does timezone conversion
    difference = range.last - range.first
    range.first + (difference / Rational(2,1)) # difference will be a Rational
  end

  # --------------------------------------------------------------------------------------------------------------
  # XML encoding and decoding support

  def build_xml(builder)
    builder.datetime do |datetime|
      _build_xml_value(datetime, :start, @s)
      _build_xml_value(datetime, :end, @e)
      datetime.precision(@p)
      datetime.timezone(@z) if @z != nil
    end
  end

  def self.new_from_xml(xml_container)
    # It's proper KDateTime XML serialisation
    start_element = xml_container.elements["datetime/start"]
    if start_element == nil
      # Quick check to see if it's parsable text string
      text = xml_container.text
      if text != nil && text =~ /\S/
        return KDateTime.new(DateTime.parse(text))
      end
      # Failed, so obviously bad serialisation
      raise "XML serialised KDateTime doesn't have a start element"
    end
    start_internal = _decode_xml_value(start_element)
    end_element = xml_container.elements["datetime/end"]
    end_internal = (end_element == nil) ? nil : _decode_xml_value(end_element)
    precision_element = xml_container.elements["datetime/precision"]
    raise "XML serialised KDateTime doesn't have a precision element" if precision_element == nil
    precision = precision_element.text
    raise "Bad precision" if precision == nil
    timezone = nil
    timezone_element = xml_container.elements["datetime/timezone"]
    if timezone_element != nil
      timezone = timezone_element.text
    end
    # The constructor will do the rest of the checking
    KDateTime.new(start_internal, end_internal, precision, timezone)
  end

  # --------------------------------------------------------------------------------------------------------------
private
  # --------------------------------------------------------------------------------------------------------------

  # Years match Postgres supported range
  DEF_ALLOWED_RANGES = [-4712..294275, 1..12, 1..31, 0..23, 0..59, 0..59]

  # How many elements required for each precision
  PRECISION_TRUNCATE = {
    'C' => 1, 'D' => 1, 'Y' => 1, 'M' => 2, 'd' => 3, 'h' => 4, 'm' => 5
  }
  LENGTH_TO_PRECISION = [nil, 'Y', 'M', 'd', 'h', 'm']

  class PFormatStr
    def initialize(plain, html = nil)
      @plain = plain
      @html = html || plain
    end
    def str(html)
      (html ? @html : @plain)
    end
  end
  HTMLSTR_TO_END_OF = PFormatStr.new(' to end of ', ' <i>to end of</i> ')
  HTMLSTR_TO = PFormatStr.new(' to ', ' <i>to</i> ')
  HTMLSTR_SPACE = PFormatStr.new(' ')
  HTMLSTR_COMMA = PFormatStr.new(', ')
  HTMLSTR_COMMA_FROM = PFormatStr.new(', from ', ', <i>from</i> ')
  HTMLSTR_EMPTY = PFormatStr.new('')
  PFormat = Struct.new(:format1, :format2, :range_sep, :range_sep_abbr, :swap_positions, :format_sep, :format_sep_abbr)

  DISPLAY_DATE_MAPPER_PLAIN = Proc.new { |d| d }
  DISPLAY_DATE_MAPPER_HTML  = Proc.new { |d| "<span>#{d}</span>" }

  PRECISION_FORMAT = {
    'C' => PFormat.new('%Yc',      nil,     HTMLSTR_TO_END_OF,    nil,               false, HTMLSTR_EMPTY),
    'D' => PFormat.new('%Ys',      nil,     HTMLSTR_TO_END_OF,    nil,               false, HTMLSTR_EMPTY),
    'Y' => PFormat.new('%Y',       nil,     HTMLSTR_TO_END_OF,    nil,               false, HTMLSTR_EMPTY),
    'M' => PFormat.new('%Y',       '%b',    HTMLSTR_TO_END_OF,    HTMLSTR_TO_END_OF, true,  HTMLSTR_SPACE),
    'd' => PFormat.new('%b %Y',    '%d',    HTMLSTR_TO_END_OF,    HTMLSTR_TO_END_OF, true,  HTMLSTR_SPACE),
    'h' => PFormat.new('%d %b %Y', '%H:00', HTMLSTR_TO,           HTMLSTR_TO,        false, HTMLSTR_COMMA, HTMLSTR_COMMA_FROM),
    'm' => PFormat.new('%d %b %Y', '%H:%M', HTMLSTR_TO,           HTMLSTR_TO,        false, HTMLSTR_COMMA, HTMLSTR_COMMA_FROM)
  }

  PG_TIMESTAMP_FORMAT = "%Y-%m-%d %H:%M:00"

  PRECISION_NEXT_UNIT = {
    'C' => [:>>, 1200], 'D' => [:>>, 120], 'Y' => [:>>, 12],
    'M' => [:>>, 1], 'd' => [:+, 1],
    'h' => [:+, Rational(1,24)], 'm' => [:+, Rational(1,24*60)]
  }

  # This is culturally specific - see notes at top of this file
  PRECISION_HAS_INSTANTANEOUS_END_POINT = {
    'h' => true,
    'm' => true
  }

  XML_FIELD_NAMES = ["year", "month", "day", "hour", "minute"]
  XML_TIMESTAMP_FORMAT = "%Y-%m-%dT%H:%M:00"

  # --------------------------------------------------------------------------------------------------------------

  def _datetime_to_internal(value, precision = nil)
    return nil if value == nil
    # Convert to an array of integers
    i = case value
    when Array
      value
    when String
      value.strip.split(/[\s\:\.\-]+/).map { |x| x.to_i }
    when DateTime, Time
      [value.year, value.month, value.mday, value.hour, value.min]
    when Date # Order of clauses is important - need to check Date *after* DateTime
      [value.year, value.month, value.mday]
    else
      raise "Invalid datetime passed to KDateTime (type not known)"
    end
    # Check i looks good
    raise "Invalid datetime passed to KDateTime (zero elements)" if i.length == 0
    i.each_with_index do |x, index|
      allowed_range = DEF_ALLOWED_RANGES[index]
      raise "Invalid datetime passed to KDateTime (bad elements)" unless x.kind_of? Fixnum
      raise "Invalid datetime passed to KDateTime (too many elements)" if allowed_range == nil
      raise "Invalid datetime passed to KDateTime (out of range at index #{index})" unless allowed_range.include?(x)
    end
    # Truncate for specified precision?
    if precision != nil
      max_len = PRECISION_TRUNCATE[precision]
      raise "Bad precision passed to KDateTime" if max_len == nil
      if i.length > max_len
        i = i[0, max_len] # truncate
      elsif i.length < max_len
        raise "Not enough precision passed to KDateTime, required #{precision}" if max_len == nil
      end
      if max_len == 1
        # Century or decades need truncating in the year value
        if precision == 'C'
          i[0] = (i[0] / 100) * 100
        elsif precision == 'D'
          i[0] = (i[0] / 10) * 10
        end
      end
    end
    i
  end

  # --------------------------------------------------------------------------------------------------------------

  # If there's a timezone, return a new datetime in GMT, otherwise return this datetime as it's processed as if it's GMT
  def _to_gmt(datetime)
    return datetime if @z == nil
    TZInfo::Timezone.get(@z).local_to_utc(datetime)
  end

  # --------------------------------------------------------------------------------------------------------------

  def _compare_times(t1, t2)
    0.upto(t1.length - 1) do |i|
      v1 = t1[i]; v2 = t2[i]
      if v1 < v2
        return -1
      elsif v1 > v2
        return 1
      end
    end
    0
  end

  # --------------------------------------------------------------------------------------------------------------

  def _internal_to_string(i)
    return '' if i == nil
    i.join(' ')
  end

  # --------------------------------------------------------------------------------------------------------------

  def _internal_to_datetime(i)
    return nil if i == nil
    DateTime.__send__(:new, *i)
  end

  # --------------------------------------------------------------------------------------------------------------

  def _to_formatted(timezone, html_output)
    # Determine formatting instructions for this precision
    format = PRECISION_FORMAT[@p]
    # Get the two dates ready for formatting
    r = [_internal_to_datetime(@s)]
    r << _internal_to_datetime(@e) if @e
    # Convert timezone?
    if timezone != nil
      r = r.map { |d| _to_gmt(d) }
      tz = TZInfo::Timezone.get(timezone)
      r = r.map { |d| tz.utc_to_local(d) }
    end
    # Format times
    r = r.map do |d|
      x = [d.strftime(format.format1)]
      x << d.strftime(format.format2) if format.format2
      x
    end
    date_mapper = html_output ? DISPLAY_DATE_MAPPER_HTML : DISPLAY_DATE_MAPPER_PLAIN
    # Need to abbreviate if they in the same time range?
    j = if r.length > 1 && format.format2 && r.first.first == r.last.first
      # Range displayed with abbrevations
      jx = [r.first.last, r.last.last].map(&date_mapper).join((format.range_sep_abbr || format.range_sep).str(html_output))
      j2 = [r.first.first].map(&date_mapper).first
      jy = (format.swap_positions ? [jx, j2] : [j2, jx])
      jy.join((format.format_sep_abbr || format.format_sep).str(html_output))
    else
      # Single value, or range displayed normally
      r = r.map { |x| [x.last, x.first] } if format.swap_positions
      r.map { |y| y.join(format.format_sep.str(html_output)) } .map(&date_mapper).join(format.range_sep.str(html_output))
    end
    # If there's not a conversion to a local time zone, but there is a timezone specified here, append it
    if timezone == nil && @z != nil
      j << " (#{@z})"
    end
    html_output ? %Q!<span class="z__object_date_value">#{j}</span>! : j
  end

  # --------------------------------------------------------------------------------------------------------------

  def _make_range
    r0 = _internal_to_datetime(@s)
    r1 = (@e ? _internal_to_datetime(@e) : r0)
    # Extend the end point by the precision time unit if
    #   1) The end point is not explicitly specified (ie just a single date entered)
    #   2) The precision unit is culturally expected to refer to an instant in time.
    if @e == nil || !(PRECISION_HAS_INSTANTANEOUS_END_POINT[@p])
      d = PRECISION_NEXT_UNIT[@p]
      r1 = r1.__send__(*d)
    end
    range = [r0, r1]
    # Apply timezone?
    (@z == nil) ? range : range.map { |t| _to_gmt(t) }
  end

  # --------------------------------------------------------------------------------------------------------------

  def _build_xml_value(builder, sym, internal)
    return if internal == nil
    attrs = {}
    internal.each_with_index { |v,i| attrs[XML_FIELD_NAMES[i]] = v }
    datetime = _internal_to_datetime(internal)
    builder.tag!(sym, datetime.strftime(XML_TIMESTAMP_FORMAT), attrs)
  end

  def self._decode_xml_value(element)
    values = []
    attrs = element.attributes
    XML_FIELD_NAMES.each_with_index do |name, index|
      v = attrs[name]
      if v != nil
        values[index] = v.to_i
      end
    end
    values
  end

  # --------------------------------------------------------------------------------------------------------------
  # JavaScript interface

  GETRANGE_RESPONSE = Java::OrgHaploJsinterfaceApp::AppDateTime::DTRange
  def jsGetRange
    range = _make_range
    r = GETRANGE_RESPONSE.new
    r.start = range.first.to_i * 1000
    r.end = range.last.to_i * 1000
    r
  end

  def jsSpecifiedAsRange
    !!(@e)
  end

end

# Workaround for http://jira.codehaus.org/browse/JRUBY-5317
Java::OrgHaploJsinterfaceApp::JRuby5317Workaround.appDateTime(KDateTime.new('2010 01 01'))
