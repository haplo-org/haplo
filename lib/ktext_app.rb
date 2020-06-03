# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KText
  # Example use: search results
  def to_summary
    # Use a cleaned up version of to_indexable by default, with HTML characters removed to be careful
    to_indexable.gsub(/<.+?>/,' ').gsub(/\s+/,' ').gsub(/\A +/,'').gsub(/ +\z/,'')
  end

  # Exporting data
  def to_export_cells
    to_s
  end

  def self.export_data_value_cell_headings(k_typecode, attr_desc)
    info = KText.get_typecode_info(k_typecode)
    if info.options.has_key?(:export_headings_fn)
      # Can have variable width; call width function
      info.options[:export_headings_fn].call(attr_desc)
    else
      # Otherwise just return array with empty string
      ['']
    end
  end

  # Truncated display -- this method is not obliged to actually do the truncation if it's not supported
  def to_truncated_html(max_length)
    # By default, don't truncate
    to_html
  end

  # To use this default truncated text implementation add:
  #   alias :to_truncated_html :to_truncated_html_default_impl
  def to_truncated_html_default_impl(max_length)
    # Make a new object of the same class with a truncated version of the underlying text string, and call its to_html method
    self.class.new(KTextUtils.truncate(@text, max_length)).to_html
  end

end

# ------------------------------------------------------------
class KTextParagraph < KText
  ktext_typecode KConstants::T_TEXT_PARAGRAPH, 'Text (paragraph)'

  def initialize(text, language = nil)
    super
  end

  def to_html
    # remember to remove \r's which IE will pop in everywhere
    # This renders a double line break as a new paragraph with single line breaks within as line breaks.
    '<p>'+(@text.gsub(/\r/,'').split(/\n{2,}/).map do |a|
      a.split(/\n/).map {|b| KTextUtils.auto_link_urls(html_escape(b))} .join('<br>')
    end .join("</p><p>"))+'</p>'
  end

  alias :to_truncated_html :to_truncated_html_default_impl
end

# ------------------------------------------------------------
class KTextDocument < KText
  ktext_typecode KConstants::T_TEXT_DOCUMENT, 'Rich text document'

  def initialize(text, language = nil)
    text = KText.ensure_utf8(text)
    # Check the text validates
    ok = false
    begin
      doc = REXML::Document.new(text)
      ok = true if (doc.root.name == self._expected_root_name)
    rescue
      # Ignore
    end
    raise "Bad XML passed to KTextDocument#initialize" unless ok
    super
  end

  # When initialising from plain text, turn it into a simple XML document
  def self.new_with_plain_text(text, attr_descriptor, language = nil)
    text = KText.ensure_utf8(text)
    builder = Builder::XmlMarkup.new
    builder.doc do |doc|
      text.split(/[\r\n]+/).each do |line|
        if line =~ /\S/
          doc.p line.chomp
        end
      end
    end
    new(builder.target!, language)
  end

  def to_xml_source
    @text
  end

  def to_indexable
    # Pull the text out of the XML
    listener = ToIndexableListener.new
    begin
      REXML::Document.parse_stream(@text, listener)
    rescue
      # Ignore errors
    end
    listener.output || ''
  end

  def to_plain_text
    # Create a relatively neat plain text version from the XML, with double newlines at the end of every paragraph or heading
    listener = ToPlainTextListener.new(self._document_initial_tag_level)
    begin
      REXML::Document.parse_stream(@text, listener)
    rescue
      # Ignore errors
    end
    listener.output || ''
  end

  def to_html
    # Pull the basic tags out of the document text
    listener = ToHTMLListener.new
    begin
      REXML::Document.parse_stream(@text, listener)
    rescue
      # Ignore errors
    end
    listener.output
  end

  def render_with_widgets(widget_renderer)
    listener = ToHTMLListener.new(nil, widget_renderer)
    REXML::Document.parse_stream(@text, listener)
    listener.output
  end

  def to_truncated_html(max_length)
    listener = ToHTMLListener.new(max_length)
    begin
      REXML::Document.parse_stream(@text, listener)
    rescue
      # Ignore errors
    end
    listener.output
  end

  def to_export_cells
    to_plain_text
  end

  def _expected_root_name
    'doc'
  end

  def _document_initial_tag_level
    0
  end

  class ToIndexableListener
    include REXML::StreamListener
    attr_reader :output
    def tag_start(name, attrs)
      @in_widget = true if name == 'widget'
    end
    def tag_end(name)
      @in_widget = nil if name == 'widget'
    end
    def text(text)
      return if @in_widget  # Ignore values in widgets!
      if @output == nil
        @output = ''.dup
      else
        @output << ' '
      end
      @output << text
    end
  end

  class ToPlainTextListener
    include REXML::StreamListener
    attr_reader :output
    def initialize(initial_tag_level)
      @output = ''.dup
      @tag_level = initial_tag_level
    end
    def tag_start(name, attrs)
      if @tag_level == 1
        @output << "\n\n" unless @output.empty? || @output =~ /\n\z/
      end
      @tag_level += 1
      @in_widget = true if name == 'widget'
    end
    def tag_end(name)
      @tag_level -= 1
      @in_widget = nil if name == 'widget'
    end
    def text(text)
      return if @in_widget || @tag_level <= 1  # Ignore values in widgets and plain text outside text tags
      @output << text
    end
  end

  # Rendering listener, supports:
  #   * truncation of output to number of characters of text
  #   * external widget renderers
  #   * auto-links things which look like URLs
  class ToHTMLListener
    include REXML::StreamListener
    TOP_LEVEL_TAG_REGEX = /\A(p|h\d+|li)\z/
    def initialize(max_chars = nil, widget_renderer = nil)
      @output = []
      @tag_level = 0
      @block_element = nil
      @chars_left = max_chars # for truncation
      @widget_renderer = widget_renderer
    end
    def tag_start(name, attrs)
      # level 0 is 'doc', level 1 is top level elements
      if @tag_level > 1
        @block_element.tag_start(name, attrs) if @block_element
      elsif @tag_level == 1
        # Only start a new block element if char count is low enough
        if @chars_left == nil || @chars_left > 0
          if name =~ TOP_LEVEL_TAG_REGEX
            @block_element = TopLevelBlockElement.new(name, @chars_left)
          elsif name == 'widget'
            @block_element = WidgetElement.new(attrs['type'], @widget_renderer)
          else
            raise "Unexpected tag in document"
          end
          @output << @block_element
        end
      end
      @tag_level += 1
    end
    def tag_end(name)
      @tag_level -= 1
      if @tag_level > 1
        @block_element.tag_end(name) if @block_element
      elsif @tag_level == 1
        if @chars_left != nil && @block_element
          new_chars_left = @block_element.chars_left
          @chars_left = new_chars_left unless new_chars_left == nil
        end
        @block_element = nil
      end
    end
    def text(text)
      @block_element.text(text) if @block_element
    end
    def output
      html = ''.dup
      current_enclosing_tag = nil
      @output.each do |block_element|
        et = block_element.enclosing_tag
        if et != current_enclosing_tag
          html << "</#{current_enclosing_tag}>" if current_enclosing_tag
          html << "<#{et}>" if et
          current_enclosing_tag = et
        end
        html << block_element.output
      end
      html << "</#{current_enclosing_tag}>" if current_enclosing_tag
      html
    end

    # Base class for top level elements
    class Block
      attr_reader :enclosing_tag
      attr_reader :chars_left
    end

    # Paragraph text with embedded character styles
    class TopLevelBlockElement < Block
      OUTPUT_TAG_REGEX = /\A(a|b|i|sub|sup)\z/
      LIST_ITEM = 'li'
      ANCHOR_TAG = 'a'
      def initialize(name, chars_left)
        @chars_left = chars_left
        @name = name
        @output = "<#{name}>".dup
        @enclosing_tag = (name == LIST_ITEM) ? 'ul' : nil
        @closing_tags = ["</#{name}>"]
      end
      def tag_start(name, attrs)
        return if @chars_left != nil && @chars_left <= 0
        if name =~ OUTPUT_TAG_REGEX
          if name == ANCHOR_TAG
            @output << %Q!<a target="_blank" rel="noopener" href="#{ERB::Util.h(attrs['href'] || '')}">!
            @in_anchor_tag = true
          else
            @output << "<#{name}>"
          end
          @closing_tags << "</#{name}>"
        end
      end
      def tag_end(name)
        return if @chars_left != nil && @chars_left <= 0
        if name =~ OUTPUT_TAG_REGEX
          @output << (@closing_tags.pop)
          @in_anchor_tag = nil if name == ANCHOR_TAG
        end
      end
      def text(text)
        if @chars_left == nil
          if @in_anchor_tag
            @output << ERB::Util.h(text)
          else
            @output << KTextUtils.auto_link_urls(ERB::Util.h(text))
          end
        else
          return if @chars_left <= 0
          trunc_text = KTextUtils.truncate(text, @chars_left)
          # Only do auto-linking when not truncating, as truncating a URL would be unhelpful
          @output << ERB::Util.h(trunc_text)
          @chars_left -= text.length # will probably make it < 0, but avoids counting the ... on truncated text
        end
      end
      def output
        if @chars_left != nil && @chars_left <= 0
          # Make sure it ends in ... if it was truncated
          @output << KTextUtils::TRUNCATION_INDICATOR unless @output.end_with?(KTextUtils::TRUNCATION_INDICATOR)
        end
        "#{@output}#{@closing_tags.reverse.join()}"
      end
    end

    # Widget top level element, externally rendered, ignored by default
    class WidgetElement < Block
      def initialize(type, widget_renderer)
        @type = type
        @spec = {}
        @widget_renderer = widget_renderer
      end
      def tag_start(name, attrs)
        if name == 'v'
          @attr = attrs['name']
        end
      end
      def tag_end(name)
      end
      def text(text)
        @spec[@attr] = text if @attr
        @attr = nil
      end
      def output
        if @widget_renderer
          @widget_renderer.call(@type, @spec)
        else
          ''
        end
      end
    end
  end

end

# ------------------------------------------------------------

class KTextFormattedLine < KTextDocument
  ktext_typecode KConstants::T_TEXT_FORMATTED_LINE, 'Formatted single line text'

  # When initialising from plain text, turn it into an XML one-liner
  def self.new_with_plain_text(text, attr_descriptor, language = nil)
    text = KText.ensure_utf8(text)
    builder = Builder::XmlMarkup.new
    builder.fl text.gsub(/\s+/,' ')
    new(builder.target!, language)
  end

  def _expected_root_name
    'fl'
  end

  # Formatted lines should behave like plain text in all cases, except when HTML is explicitly requested
  def to_s
    to_plain_text
  end

  # Formatted line doesn't have block level elements in containing <fl>,
  # and doesn't want any containing elements in the generated HTML (so if
  # it's plain text, you just get escaped plain text out).
  def _document_initial_tag_level
    1
  end

  # Easier to have it's own implementation of to_html
  def to_html
    listener = ToHTMLListenerFormattedLine.new
    begin
      REXML::Document.parse_stream(@text, listener)
    rescue
      # Ignore errors
    end
    listener.output
  end

  class ToHTMLListenerFormattedLine
    ALLOWED_TAG_REGEX = /\A(b|i|sub|sup)\z/ # no <a>
    include REXML::StreamListener
    attr_reader :output
    def initialize()
      @tag_level = 0
      @output = ''.dup
    end
    def tag_start(name, attrs)
      @tag_level += 1
      @output << "<#{name}>" if name =~ ALLOWED_TAG_REGEX
    end
    def tag_end(name)
      @tag_level -= 1
      @output << "</#{name}>" if name =~ ALLOWED_TAG_REGEX
    end
    def text(text)
      @output << ERB::Util.h(text)
    end
  end

end

# ------------------------------------------------------------
class KTextMultiline < KText
  ktext_typecode KConstants::T_TEXT_MULTILINE, 'Multiline text'

  def initialize(text, language = nil)
    super
  end

  def to_html
    # Turn line endings into brs then auto-link the URLs
    KTextUtils.auto_link_urls(html_escape(@text).gsub(/[\r\n]+/,'<br>'))
  end

  alias :to_truncated_html :to_truncated_html_default_impl
end

# ------------------------------------------------------------
class KTextPersonName < KText
  ktext_typecode KConstants::T_TEXT_PERSON_NAME, "Person's name",
    { :export_headings_fn => proc { |desc| ['Full name', 'First name', 'Last name'] } }

  def initialize(text, language = nil)
    # Is text given as hash?
    if text.class == Hash
      super encode(text), language
    else
      super
    end
  end

  NAME_SORTAS_ORDER_F_L = 'first_last'
  NAME_SORTAS_ORDER_L_F = 'last_first'
  SORTAS_ORDER_F_L = [:first, :middle, :last, :suffix, :title]
  SORTAS_ORDER_L_F = [:last, :first, :middle, :suffix, :title]
  SORTAS_ORDER_USER_OPTIONS = [
      ['First Last', NAME_SORTAS_ORDER_F_L],
      ['Last First', NAME_SORTAS_ORDER_L_F]
    ]

  PLAIN_TEXT_ORDERS = {
    1 => [:last],
    2 => [:first, :last],
    :more => [:first, :middle, :last]
  }
  def self.new_with_plain_text(text, attr_descriptor, language = nil)
    text = KText.ensure_utf8(text)
    tokens = text.strip.split
    data = Hash.new
    n = 0
    (PLAIN_TEXT_ORDERS[tokens.length] || PLAIN_TEXT_ORDERS[:more]).each do |key|
      data[key] = tokens[n]
      n += 1
    end
    # Default type?
    # TODO: Handle getting the right culture for KTextPersonName created from plain text in a less messy manner
    if attr_descriptor != nil
      # Default style?
      ui_options = attr_descriptor.ui_options
      if ui_options != nil && ui_options =~ /\A(\w)/
        culture = CULTURE_TO_SYMBOL[$1]
        data[:culture] = culture if culture != nil
      end
    end
    new(data, language)
  end

  # Format as name nicely
  def to_s
    h = self.to_fields
    # Special hack for Eastern names
    if h[:culture] == :eastern
      if h.has_key?(:last)
        h[:last] << ','
      end
    end
    # Format with space separated in order
    o = Array.new
    OUTPUT_ORDERING[h[:culture]].each do |k|
      o << h[k] if h.has_key?(k)
    end
    # Join with the right separator
    o.join(h[:culture] == :western_list ? ', ' : ' ').encode(Encoding::UTF_8)
  end

  # Use this plain text for everything else too
  alias :to_html :to_s
  alias :to_indexable :to_s
  alias :to_summary :to_s
  alias :text :to_s

  # Except for sort order, which has re-ordered elements to get a nice search order.
  # TODO: Can KTextPersonName sort as options be done a bit more elegantly?
  def to_sortas_form
    h = self.to_fields
    # Use the store options to determine sortas order
    sortas_order = if h[:culture] == :western
      # Normal western culture has optional sorting order
      (KObjectStore.schema.store_options[:ktextpersonname_western_sortas] == NAME_SORTAS_ORDER_L_F) ? SORTAS_ORDER_L_F : SORTAS_ORDER_F_L
    else
      # All others have a fixed sorting order
      SORTAS_ORDER_L_F
    end
    # Generate a string from this order
    sortas_order.map { |n| h[n] } .compact.join(' ')
  end

  # Accessor for underlying text
  def to_storage_text
    @text
  end

  # Export
  def to_export_cells
    f = to_fields
    [self.to_s, f[:first] || '', f[:last] || '']
  end

  # -- Culture information -- also used by some of the UI

  CULTURES_IN_UI_ORDER = [:western,:western_list,:eastern]

  CULTURE_TO_SYMBOL = {
    'w' => :western,
    'L' => :western_list,
    'e' => :eastern
  }

  SYMBOL_TO_CULTURE = {
    :western => 'w',
    :western_list => 'L',
    :eastern => 'e'
  }

  XML_ATTR_TO_CULTURE = {
    'western' => 'w',
    'western_list' => 'L',
    'eastern' => 'e'
  }

  FIELD_TO_SYMBOL = {
    't' => :title,
    'f' => :first,
    'm' => :middle,
    'l' => :last,
    's' => :suffix
  }
  SYMBOL_TO_FIELD = {
    :title => 't',
    :first => 'f',
    :middle => 'm',
    :last => 'l',
    :suffix => 's'
  }

  OUTPUT_ORDERING = {
    :western => [:title, :first, :middle, :last, :suffix],
    :western_list => [:last, :first, :middle, :title, :suffix],
    :eastern => [:title, :last, :middle, :first, :suffix]
  }

  FIELD_NAMES_BY_CULTURE = {
    # Also in the JS editor
    :western => {:title => 'Title', :first => 'First', :middle => 'Middle', :last => 'Last', :suffix => 'Suffix'},
    :western_list => {:title => 'Title', :first => 'First', :middle => 'Middle', :last => 'Last', :suffix => 'Suffix'},
    :eastern => {:title => 'Title', :first => 'Given', :middle => 'Middle', :last => 'Family', :suffix => 'Suffix'}
  }

  # -- Encoding and decoding

  def to_fields
    elements = @text.split("\x1f")
    output = Hash.new
    # Culture
    output[:culture] = CULTURE_TO_SYMBOL[elements.shift] || :western
    # Fields of name
    elements.each do |e|
      if e.length > 1
        # Ignore anything which is too short or has an unknown
        sym = FIELD_TO_SYMBOL[e[0,1]]
        output[sym] = e[1,e.length-1] if sym != nil
      end
    end
    output
  end

  def encode(hash)
    output = (SYMBOL_TO_CULTURE[hash[:culture]] || 'w').dup
    ordering = OUTPUT_ORDERING[hash[:culture]] || OUTPUT_ORDERING[:western]
    ordering.each do |k|
      value = hash[k]
      next if value == nil
      value = KText.ensure_utf8(value).strip
      next if value.length == 0
      field = SYMBOL_TO_FIELD[k]
      next if field == nil
      output << "\x1f"
      output << field
      output << value
    end
    output
  end

end

# ------------------------------------------------------------

class KTextPluginDefined < KText
  include KPlugin::HookSite
  ktext_typecode KConstants::T_TEXT_PLUGIN_DEFINED, 'Text (plugin defined)', {:hide => true}

  ALLOWED_TYPE_REGEX = /\A[a-z0-9_]+:[a-z0-9_]+\z/ # must never include a ~ character

  def initialize(text, language = nil)
    if text.class == Hash
      unless text[:type] && text[:type] =~ ALLOWED_TYPE_REGEX
        raise JavaScriptAPIError, "Bad type for plugin defined Text object"
      end
      @type = KText.ensure_utf8(text[:type]).dup.freeze
      super(text[:value] || '{}', language)
    else
      raise "Plugin defined text values cannot be created from strings"
    end
    # Let the plugin validate the value. It should throw an exception if the value isn't acceptable.
    transform(:validate)
  end

  def to_s
    transform(:string) || (''.dup.force_encoding(Encoding::UTF_8))
  end

  def to_sortas_form
    transform(:sortas, :string) || (''.dup.force_encoding(Encoding::UTF_8))
  end

  def to_indexable
    transform(:indexable, :string) || (''.dup.force_encoding(Encoding::UTF_8))
  end

  def to_html
    transform(:html) || (''.dup.force_encoding(Encoding::UTF_8))
  end

  def to_identifier_index_str
    idstr = transform(:identifier)
    return nil unless idstr
    if idstr.length == 0 || idstr =~ /\s/
      raise JavaScriptAPIError, "identifier transform must return a string with no whitespace"
    end
    # Include the type to distinguish between different plugin defined types, separated by a character which is not allowed in the type name
    "#{@type}~#{idstr}"
  end

  def plugin_type_name
    @type
  end

  def json_encoded_value
    @text
  end

  # Equality needs to be checked after parsing the JSON encoded data, so the properties in the JSON file can be in any order
  # This means that plugins don't have to be very careful about how they build their data structures.
  def ==(other)
    other != nil && other.class == self.class && JSON.parse(@text) == JSON.parse(other.__text) && @language == other.language
  end

  def replace_matching_ref(ref, replacement_ref)
    call_hook(:hObjectTextValueReplaceMatchingRef) do |hooks|
      output = hooks.run(@type, @text, ref, replacement_ref).output
      if output != nil
        return KTextPluginDefined.new({:type => @type, :value => output}, @language)
      end
    end
    nil
  end

  def transform(*transforms)
    transforms.each do |transform|
      call_hook(:hObjectTextValueTransform) do |hooks|
        output = hooks.run(@type, @text, transform).output
        return output if output != nil
      end
    end
    nil
  end

end
