# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



# This is only for the platform's locales, JavaScript support is provided in lib/js_support

class KLocale
  ULocale = com.ibm.icu.util.ULocale
  PluralFormat = com.ibm.icu.text.PluralFormat

  def initialize(name, name_in_language, locale_id, text_pathname, text_browser_pathname)
    @name = name.dup.freeze
    @name_in_language = name_in_language.dup.freeze
    @locale_id = locale_id.dup.freeze
    @text_lookup, @text_lookup_count_variant = KLocale.load_text(text_pathname)
    @browser_text_lookup, no_variants_for_browser = KLocale.load_text(text_browser_pathname)
    @ulocale = ULocale.new(@locale_id)
  end

  attr_reader :name, :name_in_language, :locale_id

  # -------------------------------------------------------------------------

  def text(symbol)
    @text_lookup[symbol] || begin
      if self == DEFAULT_LOCALE
        symbol.to_s.gsub('_',' ').freeze # reasonable-ish fallback
      else
        DEFAULT_LOCALE.text(symbol)
      end
    end
  end

  # -------------------------------------------------------------------------

  # Strings as arguments are HTML escaped when formatting
  def _format(format_string, args)
    safe_format_args = args.map { |v| v.kind_of?(Numeric) ? v : (v.nil? ? nil : ERB::Util.h(v.to_s)) }
    sprintf(format_string, *safe_format_args)
  end

  def text_format(symbol, *args)
    format_string = self.text(symbol)
    _format(format_string, args)
  end

  def text_format_with_count(symbol, *args)
    unless @text_lookup[symbol]
      # Delegate properly to default locale so it can do counting properly
      return DEFAULT_LOCALE.text_format_with_count(symbol, *args)
    end
    count = args.first.to_i
    variants = @text_lookup_count_variant[symbol]
    format_string = variants ? variants[count] : nil
    format_string ||= self.text(symbol)
    format_string = format_string.gsub(/\[plural (.+?)\]/) do
      PluralFormat.new(@ulocale, $1).format(count)
    end
    _format(format_string, args)
  end

  # -------------------------------------------------------------------------

  def text_lookup_for_browser(default_locale)
    if default_locale == nil
      return @browser_text_lookup
    else
      lookup = {}
      # Build lookup which uses default locale's strings if one isn't present in translation
      default_locale.text_lookup_for_browser(nil).each do |symbol,text|
        lookup[symbol] = @browser_text_lookup[symbol] || text
      end
      lookup
    end
  end

  def self.browser_text_lookup_to_js(lookup)
    %Q!KUIText=#{JSON.generate(lookup)};!
  end

  # -------------------------------------------------------------------------

  def self.load_text(text_pathname)
    lookup = {}
    lookup_count_variant = {}
    File.open(text_pathname, "r:UTF-8") do |file|
      file.each do |line|
        if line !~ /\A\s*\#/ && line =~ /\A([A-Z0-9a-z_]+?)(__count(\d+))?\s*=\s*(.+)\s*\z/
          symbol = $1.to_sym
          text = $4.dup.freeze
          if $3 # this is a count variant
            raise "Default count variant must be defined before count variant '#{line}'" unless lookup.has_key?(symbol)
            (lookup_count_variant[symbol] ||= {})[$3.to_i] = text
          else
            lookup[symbol] = text
          end
        end
      end
    end
    [lookup.freeze, lookup_count_variant.freeze]
  end

  # -------------------------------------------------------------------------

  # Default locale-specific text transformations, for overriding in locale classes
  def possessive_case_of(name)
    name # most languages don't need any changes
  end

  # -------------------------------------------------------------------------

  # Provide to JavaScript
  def self._locale_initialiser_for_javascript(default_locale, locales)
    info = {}
    text = {}
    locales.each do |locale|
      text[locale.locale_id] = locale.__text_lookup
      info[locale.locale_id] = {
        "id" => locale.locale_id,
        "name" => locale.name,
        "nameInLanguage" => locale.name_in_language
      }
    end
    "$i18n_locale_info = #{JSON.generate(info)};\n$i18n_platform_text = #{JSON.generate(text)};$i18n_defaults={'locale_id':'#{default_locale.locale_id}'};"
  end
  def __text_lookup
    @text_lookup
  end

  # -------------------------------------------------------------------------

  # For testing
  def _all_symbols
    [@text_lookup.keys, @browser_text_lookup.keys]
  end

end
