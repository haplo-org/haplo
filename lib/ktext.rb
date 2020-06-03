# frozen_string_literal: true

# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KText
  include Java::OrgHaploJsinterfaceApp::AppText

  attr :text
  attr :language

  TextTypeInfo = Struct.new(:typecode, :type_class, :name, :hide, :options)

  # Allow subclasses to register their types, and implement the k_typecode method
  def self.ktext_typecode(typecode, name, options = {})
    define_method(:k_typecode) do
      typecode
    end
    @@typecode_info ||= Hash.new
    @@typecode_info[typecode] = TextTypeInfo.new(typecode, self, name, options[:hide] || false, options)
  end
  ktext_typecode KConstants::T_TEXT, 'Text (single line)'

  def self.get_typecode_info(typecode)
    @@typecode_info[typecode]
  end
  def self.all_typecode_info
    @@typecode_info.values.sort { |a,b| a.name <=> b.name }
  end

  def self.ensure_utf8(text)
    raise "KText cannot use non-String objects" unless text.is_a? String
    text = text.encode(Encoding::UTF_8) if text.encoding == Encoding::US_ASCII
    raise "KText can only use UTF-8 or US-ASCII encoded strings (got #{text.encoding.name})" unless text.encoding == Encoding::UTF_8
    text
  end

  def initialize(text, language = nil)
    @text = KText.ensure_utf8(text).dup.freeze   # make a frozen copy for safety, so things can't modify it under us
    if language != nil
      raise "language for KText must be nil or symbol" unless language.class == Symbol
      @language = language
    end
  end

  # For overriding
  def self.new_with_plain_text(text, attr_descriptor, language = nil)
    new(text, language)
  end

  def self.new_by_typecode(typecode, text, language = nil)
    info = @@typecode_info[typecode.to_i]
    raise "No KText derived class for #{typecode}" if info == nil
    info.type_class.new(text, language)
  end

  def self.new_by_typecode_plain_text(typecode, plain_text, attr_descriptor, language = nil)
    info = @@typecode_info[typecode.to_i]
    raise "No KText derived class for #{typecode}" if info == nil
    info.type_class.new_with_plain_text(plain_text, attr_descriptor, language)
  end

  def __text
    @text
  end
  def ==(other)
    other != nil && other.class == self.class && @text == other.__text && @language == other.language
  end
  def eql?(other)
    other != nil && self == other
  end
  def hash
    @text.hash
  end

  # Conversion to various formats (should be overridden by subclasses)
  def to_s
    @text
  end
  def to_plain_text
    self.to_s
  end
  def to_storage_text   # for sending to the javascript object editor, or exporting
    @text
  end
  def to_sortas_form    # sortable form for determining sort order
    @text
  end
  def to_indexable
    @text
  end
  def to_identifier_index_str
    nil                 # generally text is not an identifier
  end
  def to_html
    html_escape(@text)
  end

  # Processed terms ready for direct use in the index
  def to_terms
    indexable = self.to_indexable
    (indexable == nil) ? nil : KTextAnalyser.text_to_terms(indexable)
  end
  # Is using to_terms a computationally expensive action?
  def to_terms_is_slow?
    false
  end
  # What value should be used for comparisons to see if the text has changed enough for reindexing linked objects?
  # This should be as quick as possible to generate.
  def to_terms_comparison_value
    to_indexable()
  end

  # Utility function
  def html_escape(s)
    s.to_s.gsub(/&/, "&amp;").gsub(/\"/, "&quot;").gsub(/>/, "&gt;").gsub(/</, "&lt;")
  end
end

# Workaround for http://jira.codehaus.org/browse/JRUBY-5317
Java::OrgHaploJsinterfaceApp::JRuby5317Workaround.appText(KText.new(''))
