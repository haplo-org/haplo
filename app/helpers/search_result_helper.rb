# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

module SearchResultHelper

  class ResultRenderer
    include ERB::Util
    include KConstants

    MAX_COLUMNS = 3
    LINES_IN_COLUMN = 4
    AUTO_DISPLAYABLE_TYPECODES = {
      T_OBJREF => true,
      T_TEXT => true, T_IDENTIFIER_ISBN => true, T_IDENTIFIER_EMAIL_ADDRESS => true, T_IDENTIFIER_URL => true,
      T_IDENTIFIER_TELEPHONE_NUMBER => true, T_TEXT_PERSON_NAME => true
    }
    SINGLE_LINE_TYPECODES = AUTO_DISPLAYABLE_TYPECODES  # same list

    # ------------------------------------------------------------------------------------------------------------------------------

    def initialize(object, controller, options)
      @object = object
      @controller = controller
      @options = options || {}
      @columns = []
      @seen_descs = [A_TITLE, A_TYPE] # stops automatic_value_display() using titles and types
      # Plugins can customise the search result display
      runtime = KJSPluginRuntime.current
      json = runtime.call_search_result_render(object)
      if json
        begin
          actions = JSON.parse(json)
          _apply_actions(actions) if actions && actions.kind_of?(Array)
        rescue => e
          # Log, but otherwise ignore
          KApp.logger.log_exception(e)
        end
      end
    end

    attr_accessor :no_default_rendering

    # Second line
    def line2_from(*arguments);       @line2_html = _from_to_html(*arguments); end
    def line2=(text);                 @line2_html = h(text); end
    def line2_html=(html);            @line2_html = html; end
    def has_line2?;                   !!(@line2_html); end
    def line2_append(text)            @line2_html ||= ''; @line2_html << h(text); end
    def line2_append_if(text)         @line2_append_html = h(text); end
    # Second line right
    def line2_right_from(*arguments); @line2_right_html = _from_to_html(*arguments); end
    def line2_right=(text);           @line2_right_html = h(text); end
    def line2_right_html=(html);      @line2_right_html = html; end
    def has_line2_right?;             !!(@line2_right_html); end

    def mark_attribute_as_used(desc)
      @seen_descs << desc
    end

    def display_attributes(desc, caption = nil, show_qualifiers = true)
      return if @seen_descs.include?(desc)
      @seen_descs << desc
      if caption === :caption_from_schema
        ad = _schema.attribute_descriptor(desc)
        caption = ad ? ad.printable_name.to_s : nil
      end
      values = [];
      @object.each(desc) { |v,d,q| values << [v,q] }
      return if values.empty?
      @columns << ColumnValues.new(desc, caption, values, show_qualifiers)
    end

    def display_text(text, width = 1, caption = nil)
      @columns << ColumnHTML.new(_with_caption(h(text), caption), width)
    end

    def display_html(html, width = 1, caption = nil)
      @columns << ColumnHTML.new(_with_caption(html, caption), width)
    end

    def automatic_value_display
      transformed = KAttrAlias.attr_aliasing_transform(@object, _schema) do |value,desc,q|
        !(@seen_descs.include?(desc)) && AUTO_DISPLAYABLE_TYPECODES[value.k_typecode]
      end
      transformed.each do |t|
        unless t.attributes.empty?
          @columns << ColumnValues.new(t.descriptor.desc, t.descriptor.printable_name.to_s, t.attributes.map { |v,d,q| [v,q] }, true)
        end
      end
    end

    def number_of_columns
      @columns.length
    end

    def to_html
      _merge_columns()
      _fill_unused_columns_with_summary_text() unless @no_default_rendering
      _adjust_columns_to_fit()

      html = (@line2_html || @line2_right_html) ? '<h3>' : '<h3 class="z__two_line">'
      html << @controller.link_to_object_with_title(@object)
      html << '</h3>'
      if @line2_html
        html << (@line2_right_html ? '<h4 class="z__second_title_short_for_right">' : '<h4>')
        html << @line2_html
        html << @line2_append_html if @line2_append_html
        html << '</h4>'
      end
      if @line2_right_html
        html << '<h4 class="z__second_title_right">'
        html << @line2_right_html
        html << '</h4>'
      end
      html << '<div class="z__searchresult_information_container">'
      @columns.each do |column|
        html << column.to_html(@controller, @object, @options)
      end
      html << '</div>'
      html
    end

    # ------------------------------------------------------------------------------------------------------------------------------

    def _from_to_html(quantity, desc)
      @seen_descs << desc
      if quantity == :all
        values = @object.all_attrs(desc)
        return nil if values.empty?
        values.map { |v| @controller.render_value(v, @object, @options, desc) } .join(', ')
      else
        value = @object.first_attr(desc)
        value ? @controller.render_value(value, @object, @options, desc) : nil
      end
    end

    def _merge_columns()
      return if (@columns.length <= MAX_COLUMNS) && @no_default_rendering
      merged = []
      loop do
        break unless (c = @columns.shift)
        if !(merged.empty?) && merged.last.can_merge_with?(c)
          merged << ColumnMerged.new(merged.pop, c)
        else
          merged << c
        end
      end
      @columns = merged
    end

    def _fill_unused_columns_with_summary_text
      columns_to_fill = MAX_COLUMNS - _total_column_width()
      return unless columns_to_fill > 0
      summary = @controller.obj_display_highlighted_summary_text(@object, 2, @options[:keywords], 160, @seen_descs)
      if summary
        @columns << ColumnHTML.new('<div>'+summary.join('</div><div>')+'</div>', columns_to_fill)
      end
    end

    def _adjust_columns_to_fit
      return if @columns.empty?
      tw = _total_column_width()
      if tw < MAX_COLUMNS
        # Find columns with the biggest expansion score, add the extra width to it
        @columns.sort_by { |c| c.expansion_score }.last.width += MAX_COLUMNS - tw
      elsif tw > MAX_COLUMNS
        # Too wide, remove some columns
        loop do
          @columns.pop
          break if _total_column_width() <= MAX_COLUMNS
        end
      end
    end

    def _total_column_width
      @columns.inject(0) { |total,column| column.width + total }
    end

    def _schema
      @_schema ||= KObjectStore.schema
    end

    def self._is_single_line(value)
      SINGLE_LINE_TYPECODES[value.k_typecode]
    end

    def _with_caption(html, caption)
      caption ? %Q!<div class="z__searchresult_information_line z__searchresult_value_caption">#{h(caption)}</div>#{html}! : html
    end

    # ------------------------------------------------------------------------------------------------------------------------------

    ACTIONS = {
      'no-default' => Proc.new { |r,a| r.no_default_rendering = true },
      'hide-descs' => Proc.new { |r,a|
        (a['descs'] || []).each { |v| r.mark_attribute_as_used(v.to_i) }
      },
      'text' => Proc.new { |r,a|
        case a["destination"]
        when 'subtitle';        r.line2 = a['text']
        when 'subtitle-right';  r.line2_right = a['text']
        when 'column';          r.display_text(a['text'], (a['width'] || 1).to_i, a['caption'])
        end
      },
      'html' => Proc.new { |r,a|
        case a["destination"]
        when 'subtitle';        r.line2_html = a['html']
        when 'subtitle-right';  r.line2_right_html = a['html']
        when 'column';          r.display_html(a['html'], (a['width'] || 1).to_i, a['caption'])
        end
      },
      'values' => Proc.new { |r,a|
        case a["destination"]
        when 'subtitle';        r.line2_from(a['all'] ? :all : :first, a['desc'].to_i)
        when 'subtitle-right';  r.line2_right_from(a['all'] ? :all : :first, a['desc'].to_i)
        when 'column';
          caption = a['autoCaption'] ? :caption_from_schema : a['caption']
          r.display_attributes(a['desc'].to_i, caption, !!(a['showQualifiers']))
        end
      },
      'subtitle-append-if' => Proc.new { |r,a|
        r.line2_append_if(a['text'])
      }
    }

    def _apply_actions(actions)
      # IMPORTANT - CONTENTS OF actions IS UNTRUSTED
      actions.each do |action|
        p = ACTIONS[action['action']]
        p.call(self, action) if p
      end
    end

    # ------------------------------------------------------------------------------------------------------------------------------

    # Base class for columns
    class Column
      WIDTH_TO_COLUMN_CLASS = ['', 'z__searchresult_information_1', 'z__searchresult_information_2', 'z__searchresult_information_3'] # full names because CSS rewriting
      def initialize(width)
        @width = (width > 0 && width < WIDTH_TO_COLUMN_CLASS.length) ? width : 1
      end
      attr_accessor :width
      def to_html(controller, object, options)
        %Q!<div class="#{WIDTH_TO_COLUMN_CLASS[@width || 1]}">#{make_inner_html(controller, object, options)}</div>!
      end
      def make_inner_html(controller, object, options)
        ''
      end
      def expansion_score
        0
      end
      def height
        9999  # always a large height
      end
      def can_merge_with?(other)
        false
      end
    end

    # Any old HTML
    class ColumnHTML < Column
      def initialize(html, width = 1)
        super(width)
        @html = html
      end
      def make_inner_html(controller, object, options)
        @html
      end
      def expansion_score
        @html.length  # longer it is, better the chance of expansion
      end
    end

    # Column containing values from the object, and maybe the headings
    class ColumnValues < Column
      include ERB::Util
      include KConstants
      def initialize(desc, caption, values, show_qualifiers, width = 1)
        super(width)
        @desc = desc
        @caption = caption
        @show_qualifiers = show_qualifiers
        @values = []
        @height = caption ? 1 : 0
        # Choose up to the column height's worth of values
        values.each do |x|
          single_line = ResultRenderer._is_single_line(x.first)
          x << single_line
          h = single_line ? 1 : ResultRenderer::LINES_IN_COLUMN
          if (@height + h) > ResultRenderer::LINES_IN_COLUMN
            @is_truncated = true
            break
          end
          @values << x
          @height += h
        end
      end
      def make_inner_html(controller, object, options)
        schema = nil
        html = @is_truncated ? '<div class="z__searchresult_information_truncated">...</div>' : ''
        html << %Q!<div class="z__searchresult_information_line z__searchresult_value_caption">#{h(@caption)}</div>! if @caption
        @values.each do |value,qual,single_line|
          html << '<div class="z__searchresult_information_line">' if single_line
          html << controller.render_value(value, object, options, @desc)
          if @show_qualifiers && qual != Q_NULL
            schema ||= KObjectStore.schema
            qd = schema.qualifier_descriptor(qual)
            html << %Q! <i>(#{h(qd.printable_name.to_s)})</i>! if qd
          end
          html << '</div>' if single_line
        end
        html
      end
      def expansion_score
        @values.length * 8 # HTML will probably get expanded before this
      end
      def height
        @height
      end
      def can_merge_with?(other)
        (@height + other.height) <= ResultRenderer::LINES_IN_COLUMN
      end
    end

    # Two columns merged into one
    class ColumnMerged < Column
      def initialize(a, b)
        super([a.width, b.width].max)
        @a = a
        @b = b
      end
      def expansion_score
        @a.expansion_score + @b.expansion_score
      end
      def height
        @a.height + @b.height
      end
      def make_inner_html(controller, object, options)
        @a.make_inner_html(controller, object, options) + @b.make_inner_html(controller, object, options)
      end
    end
  end

end
