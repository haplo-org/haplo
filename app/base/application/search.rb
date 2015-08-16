# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class ApplicationController

  POSSIBLE_USER_SORT_OPTIONS = {
    'date' => :date,            :date => :date,
    'title' => :title,          :title => :title,
    'relevance' => :relevance,  :relevance => :relevance
  }

  ALLOWED_SEARCH_RENDER_STYLE = {
    'mini' => true,
    'cal' => true
  }
  SEARCH_RENDER_STYLE_TO_RENDER = Hash.new(:searchresult)
  SEARCH_RENDER_STYLE_TO_RENDER['mini'] = :searchresultmini

  # -----------------------------------------------------------------------
  # Make a search specification suitable for perform_search_for_rendering() from a hash
  # Returns nil if nothing for a search is possible
  def search_make_spec(from)
    # Main query string
    query_string = from[:q]
    query_string = nil unless query_string != nil && query_string =~ /\S/
    # Search within string
    search_within = from[:w]
    search_within = nil unless search_within != nil && search_within =~ /\S/
    # Fields
    fields_string = nil
    fields_obj = nil
    if from.has_key?(:f)
      # Detokenise the results from the editor
      fields_obj = search_detokenise_encoded_fields(from[:f])
      # Build a search string
      # Do this rather than building a query from the fields so that all the abilities of the query parser can be used
      schema = KObjectStore.schema
      items = Array.new
      fields_obj.each do |value,desc,qualifier|
        attr_desc = schema.attribute_descriptor(desc)
        if attr_desc != nil
          items << if value.kind_of? KObjRef
            v = "#L#{value.to_presentation}/d#{desc}"
            v << "/q#{qualifier}" if qualifier != nil
            v << "#"
            v
          else
            qual_desc = (qualifier == nil) ? nil : schema.qualifier_descriptor(qualifier)
            qual_desc_s = (qual_desc == nil) ? nil : "/#{qual_desc.short_name}"
            field_prefix = "#{attr_desc.short_name}#{qual_desc_s}:"
            v = value.to_s.gsub(/[\(\)]/,'')  # Remove brackets, to avoid making dodgy queries which won't work very well
            next if v.empty?
            "#{field_prefix}#{v}"
          end
        end
      end
      fields_string = items.join(' ') unless items.empty?
    end

    # If there's no searching to do, give up now
    return nil if query_string == nil && search_within == nil && fields_string == nil

    # Form basic specification...
    spec = Hash.new
    spec[:q] = query_string if query_string != nil
    spec[:w] = search_within if search_within != nil
    if fields_string != nil
      spec[:f] = from[:f]
      spec[:f_query] = fields_string
      spec[:f_obj] = fields_obj
    end
    # ... then add options

    # Sorting
    sort = POSSIBLE_USER_SORT_OPTIONS[from[:sort]]
    spec[:sort] = sort if sort != nil

    # Subset
    if from.has_key?(:subset)
      subset_ref = KObjRef.from_presentation(from[:subset])
      spec[:subset] = subset_ref if subset_ref != nil
    end

    # Type restriction
    if from.has_key?(:type)
      type_refs = from[:type].split(',')
      # First element might be '_' for filtering with types and subtypes
      with_subtypes = false
      if type_refs.length > 0 && type_refs.first == '_'
        with_subtypes = true
        type_refs.shift
      end
      type_refs = type_refs.map { |r| KObjRef.from_presentation(r) }
      type_refs.compact!  # remove nils (eg if string is 'all')
      unless type_refs.empty?
        spec[:type] = type_refs
        spec[:type_filter_kind] = :with_subtypes if with_subtypes
      end
    end

    # Render style
    if from.has_key?(:rs)
      spec[:render_style] = from[:rs] if ALLOWED_SEARCH_RENDER_STYLE[from[:rs]]
    end

    # Make audit entry version of the spec, with just the minimum details
    audit = {}
    audit[:q] = query_string.strip if query_string
    audit[:w] = search_within.strip if search_within
    audit[:f] = spec[:f_query] if fields_string
    audit[:subset] = spec[:subset].to_presentation if spec.has_key?(:subset)
    spec[:audit] = audit

    spec
  end

  # -----------------------------------------------------------------------
  # Detokenise encoded fields object
  def search_detokenise_encoded_fields(encoded)
    schema = KObjectStore.schema
    fields_obj = KObject.new()
    fields_obj.add_attr(schema.root_types.first, A_TYPE) # Any type will do
    KEditor.apply_tokenised_to_obj(encoded, fields_obj)
    fields_obj.delete_attrs!(A_TYPE) # Remove the arbitary type added
    fields_obj
  end

  # -----------------------------------------------------------------------
  # URL parameters for making links
  def search_url_params(spec, *without)
    p = []
    # Subset
    p << "subset=#{spec[:subset].to_presentation}" if spec.has_key?(:subset) && !without.include?(:subset)
    # Sort
    p << "sort=#{spec[:sort]}" if spec.has_key?(:sort) && !without.include?(:sort)
    # Type
    if spec.has_key?(:type) && !without.include?(:type)
      p << "type=#{(spec[:type_filter_kind] == :with_subtypes) ? '_,' : nil}#{spec[:type].map { |r| r.to_presentation} .join(',')}"
    end
    # Render style
    rs = spec[:render_style]
    p << "rs=#{rs}" if rs != nil && ALLOWED_SEARCH_RENDER_STYLE[rs] && !without.include?(:render_style)
    # Optional search within string
    p << "w=#{ERB::Util.url_encode(spec[:w])}" if spec.has_key?(:w) && !without.include?(:w)
    # Query string
    p << "q=#{ERB::Util.url_encode(spec[:q])}"
    # Fields
    p << "f=#{ERB::Util.url_encode(spec[:f])}" if spec.has_key?(:f) && !without.include?(:f)
    # Join into one set of parameters
    p.join('&')
  end

  # And a version for creating form parameters
  # -- slightly different, will exclude the :q parameter if asked
  def search_params_as_hidden(spec, *without)
    p = ''
    p << %Q!<input type="hidden" name="subset" value="#{spec[:subset].to_presentation}">! if spec.has_key?(:subset) && !without.include?(:subset)
    p << %Q!<input type="hidden" name="sort" value="#{spec[:sort]}">! if spec.has_key?(:sort) && !without.include?(:sort)
    if spec.has_key?(:type) && !without.include?(:type)
      p << %Q!<input type="hidden" name="type" value="#{(spec[:type_filter_kind] == :with_subtypes) ? '_,' : nil}#{spec[:type].map { |r| r.to_presentation} .join(',')}">!
    end
    rs = spec[:render_style]
    p << %Q!<input type="hidden" name="rs" value="#{rs}">! if rs != nil && ALLOWED_SEARCH_RENDER_STYLE[rs] && !without.include?(:render_style)
    p << %Q!<input type="hidden" name="w" value="#{ERB::Util.html_escape(spec[:w])}">! if spec.has_key?(:w) && !without.include?(:w)
    p << %Q!<input type="hidden" name="q" value="#{ERB::Util.html_escape(spec[:q])}">! unless without.include?(:q)
    p << %Q!<input type="hidden" name="f" value="#{ERB::Util.html_escape(spec[:f])}">! if spec.has_key?(:f) && !without.include?(:f)
    p
  end

  # -----------------------------------------------------------------------
  # Which attributes go in search by fields?
  def search_by_fields_attributes
    a = KApp.global(:search_by_fields)
    if a == nil
      KConstants::DEFAULT_SEARCH_BY_FIELDS_ATTRS
    else
      a.split(',').map { |desc| desc.to_i }
    end
  end

  # -----------------------------------------------------------------------
  # Object to search by fields display HTML (summarises options)
  def search_by_fields_obj_to_summary(obj)
    schema = KObjectStore.schema
    fields_items = Array.new
    obj.each do |value,desc,qualifier|
      attr_desc = schema.attribute_descriptor(desc)
      i = "<i>"
      if attr_desc != nil
        i << attr_desc.short_name.to_s
        qual_desc = (qualifier == nil) ? nil : schema.qualifier_descriptor(qualifier)
        if qual_desc != nil
          i << '/'
          i << qual_desc.short_name.to_s
        end
        i << ':</i>'
        if value.kind_of? KObjRef
          obj = KObjectStore.read(value)
          i << "<b>#{h(obj.first_attr(KConstants::A_TITLE).to_s)}</b>"
        else
          i << h(value.to_s)
        end
      end
      fields_items << i
    end
    if fields_items.empty?
      ''
    else
      "<span>#{fields_items.join('</span> AND <span>')}</span>"
    end
  end

  # -----------------------------------------------------------------------
  # Run search given specification
  #
  # Specification has keys
  #   :q => query as string
  #   :sort => sort spec
  #   :subset => KObjRef of subset to search
  #
  # Options:
  #   :query_execute_results => first parameter to query execute command, defaults to :reference
  #
  def perform_search_for_rendering(spec)
    r = nil

    query_string = spec[:q]
    search_within = spec[:w]
    fields_string = spec[:f_query]
    if query_string != nil || search_within != nil || fields_string != nil
      # Make a KQuery objects -- can't just AND strings together because of syntax errors, bad brackets could change meaning
      queries = Array.new
      [query_string, search_within, fields_string].each do |q|
        next unless q != nil
        parsed = KQuery.from_string(q)
        queries << parsed unless parsed.empty?
      end

      # Special case for calendars
      is_calendar_style = spec[:render_style] == 'cal'

      # Execute query, if there's something in it
      unless queries.empty?
        store_query = KObjectStore.query_and
        errors = []
        queries.each { |q| q.add_query_to(store_query, errors) }

        # Non-empty but malformed parsed queries may result in empty store queries
        return nil if store_query.empty?

        if is_calendar_style
          # If we're doing a calendar, only show the events which are after the beginning of today (- an hour to avoid midnight issues)
          store_query.and.date_range(1.hour.ago.beginning_of_day(), nil, A_DATE)
        end

        # Make flags; use the search within query first so user can override flags in the search within field
        flags = {}
        queries.reverse_each { |q| flags.merge!(q.flags) }  # make sure the main 'q' query goes last

        # Include structure objects?
        unless flags.has_key?(:include_structure_objects)
          store_query.add_exclude_labels([O_LABEL_STRUCTURE])
        end
        # Include CONCEPT (=classification) types?
        unless flags.has_key?(:include_concept_objects)
          store_query.add_exclude_labels([O_LABEL_CONCEPT])
        end
        # Include ARCHIVED objects?
        if flags.has_key?(:include_archived_objects)
          store_query.include_archived_objects(:include_archived)
        end
        # Search for DELETED objects only?
        if flags.has_key?(:deleted_objects_only)
          store_query.include_deleted_objects(:deleted_only)
        end

        subset = nil
        if spec.has_key?(:subset)
          subset = KObjectStore.read(spec[:subset])
        end

        # Constrain the search by the subset?
        if subset && @request_user.policy.can_search_subset_be_used?(subset)
          # Labels from subset
          store_query.add_label_constraints(subset.all_attrs(A_INCLUDE_LABEL))
          store_query.add_exclude_labels(subset.all_attrs(A_EXCLUDE_LABEL))
          # Types constraint from subset
          subset_include_types = subset.all_attrs(A_INCLUDE_TYPE)
          unless subset_include_types.empty?
            subset_type_constraint = store_query.or
            subset_include_types.each { |t| subset_type_constraint.link(t, A_TYPE) }
          end
        end

        # Choose a sorting method...
        # Relevance choice possible?
        relevance_possible = store_query.can_order_by_relevance?

        # Choose sort by
        sort = (relevance_possible) ? :relevance : :date
        if sort != nil
          ss = spec[:sort]
          sort = ss if ss == :date || ss == :title
        end
        if is_calendar_style
          # Calendars need to be sorted by the date field, not anything else
          sort = KObjectStore::DateFieldSorter.new(:asc, A_DATE)
        end

        # Limit number of results returned?
        store_query.maximum_results(spec[:maximum_results]) if spec.has_key? :maximum_results

        # Execute the query (optional type counts)
        opts = Hash.new
        opts[:with_type_counts] = true if spec[:with_type_counts]
        opts[:type_filter] = spec[:type] if spec.has_key?(:type)
        opts[:type_filter_kind] = spec[:type_filter_kind] if spec.has_key?(:type_filter_kind)

        results = store_query.execute(spec[:query_execute_results] || :reference, sort, opts);

        # Return the sort specification merged with the results
        r = spec.merge({ :results => results,
              :query_string => query_string || '',
              :search_within => search_within || '',
              :errors => errors,
              :sort => is_calendar_style ? :date : sort,  # hack to make the links work nicely
              :keywords_for_display => store_query.keywords_for_summary_highlighting,
              :relevance_possible => relevance_possible })
        # Add in subset info, if used
        r[:subset_object] = subset if subset != nil
      end
    end

    r
  end


  # -----------------------------------------------------------------------
  # Search subsets
  def subsets_for_current_user
    # Cache the result in the controller so it can be called multiple times in the same request without re-querying the store
    @_subsets_for_current_user ||= begin
      subsets = KObjectStore.query_and.link(O_TYPE_SUBSET_DESC, A_TYPE).execute(:all, :title)
      user_subsets = []
      subsets.each do |subset|
        user_subsets << subset if @request_user.policy.can_search_subset_be_used?(subset)
      end
      # Sort by ordering
      user_subsets.sort { |a,b| a.first_attr(A_ORDERING) <=> b.first_attr(A_ORDERING) }
    end
  end

end
