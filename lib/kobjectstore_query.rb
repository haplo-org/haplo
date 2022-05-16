# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# (c) Avalara, Inc 2021
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



# Queries are split into two parts: the user query and the constraints.
# Use constraints_container to get a container for the constraints.


# NOTE
#  For optimisation, see http://www.postgresql.org/docs/8.1/interactive/explicit-joins.html

# TODO: KObjectStore query benchmarking and optimisation

# TODO: Check the behaviour of NOT clauses -- not quite intutive. Maybe needs addressing in the rewrite, as this is mostly an SQL limitation.

class KObjectStore
  # Create a new query object
  def query_and; QueryAnd.new(self) end
  def query_or; QueryOr.new(self) end

  # Functionality for queries
  module Query

    # Not all queries can be ordered by relevance -- use the existence of highlighting words to check
    def can_order_by_relevance?
      words = Array.new
      collect_words_for_summary_highlighting words
      words.length > 0
    end

    # Get words for highlighting, returns nil if none
    def keywords_for_summary_highlighting
      words = Array.new
      collect_words_for_summary_highlighting words
      (words.empty?) ? nil : words
    end

    # Spelling corrections for simple queries. Returns nil if there's nothing to suggest.
    def suggest_spellings(query)
      # TODO: Implement suggest_spellings() in a cleaner and more complete manner.
      return nil unless query =~ /\A\s*([a-zA-Z0-9-]+\s*:)?([^:()->]+)\z/
      field = $1
      keywords = $2
      normalised = KTextAnalyser.sort_as_normalise(keywords)
      words_out = Array.new
      KApp.with_pg_database do |db|
        db.exec(%Q!SELECT oxp_reset()!)
        db.exec(%Q!SELECT oxp_open(2,'#{@store.get_text_index_path(:full)}')!)
        different = false
        words = normalised.split(/\s+/)
        return nil if words.length > 12 # not too many
        words.each do |word|
          r = db.exec("SELECT oxp_spelling(2, $1)", word)
          x = r.first.first
          if x.length > 0 && x != word
            different = true
            words_out << x
          else
            words_out << word
          end
        end
        return nil unless different
        # Quote operators
        words_out.map! do |w|
          KQuery::OPERATIONS.has_key?(w.downcase) ? %Q!"#{w}"! : w
        end
      end
      "#{field}#{words_out.join(' ')}"
    end

    # ----------------------------------------------------------------------------------------------------

    # Labels
    # PERM TODO: Where should the label exclusions in queries go? Every level of clause? Or just top level? And named right?
    def add_exclude_labels(labels)
      @exclude_labels = ((@exclude_labels || []) + labels.map { |l| l.to_i }).sort.uniq
      self
    end

    # PERM TODO: add_label_constraints not pretty, and needs a proper Clause implementation
    # Matching objects must include *all* the label constraints (not just one of them)
    def add_label_constraints(labels)
      @label_constraints = ((@label_constraints || []) + labels.map { |l| l.to_i }).sort.uniq
      self
    end

    VALID_DELETED_OBJECT_INCLUSIONS = [:exclude_deleted, :deleted_only, :ignore_deletion_label]
    # Remember to use this, rather than adding O_LABEL_DELETED manually
    def include_deleted_objects(inclusion)
      raise "include_deleted_objects already set for this query" unless @deleted_objects == nil
      raise "Bad include_deleted_objects() value #{inclusion}" unless VALID_DELETED_OBJECT_INCLUSIONS.include?(inclusion)
      @deleted_objects = inclusion
      self
    end

    VALID_ARCHIVED_OBJECT_INCLUSIONS = [:exclude_archived, :include_archived]
    def include_archived_objects(inclusion)
      raise "include_archived_objects already set for this query" unless @archived_objects == nil
      raise "Bad include_archived_objects() value #{inclusion}" unless VALID_ARCHIVED_OBJECT_INCLUSIONS.include?(inclusion)
      @archived_objects = inclusion
      self
    end

    # ----------------------------------------------------------------------------------------------------
    #   QUERY EXECUTION
    # ----------------------------------------------------------------------------------------------------

    # style     :reference (default: just the refs), :all (entire object)
    # sort_by   :date (default), :date_asc, :relevance, :any, :title, :title_desc
    def execute(results = :reference, sort_by = :date, options = {})
      self.store.statistics.inc_query
      # Apply labels exclusion/constraints for deleted objects
      # Note that if the caller adds O_LABEL_DELETED labels itself, it can confuse things
      case @deleted_objects || :exclude_deleted
      when :exclude_deleted
        add_exclude_labels([KConstants::O_LABEL_DELETED])
      when :deleted_only
        add_label_constraints([KConstants::O_LABEL_DELETED])
      else
        # Don't do anything
      end
      # Archived objects are excluded by default from all searches
      if @archived_objects != :include_archived
        add_exclude_labels([KConstants::O_LABEL_ARCHIVED])
      end

      # Make sure that if a type filter is specified, then type counts are requested (assumption made by rest of code)
      if options.has_key?(:type_filter) && !(options[:with_type_counts])
        options = options.dup
        options[:with_type_counts] = true
      end

      # Empty results if no clauses
      unless has_clauses?
        return Results.new(@store, nil, [], nil, nil)
      end

      data = nil
      KApp.with_pg_database do |db|
        begin
          # Setup Xapian interface
          sql = 'SELECT oxp_reset(); '.dup
          required_text_indicies = collect_required_textidx(0)
          if (required_text_indicies & Clause::TEXTIDX_FULL) == Clause::TEXTIDX_FULL
            sql << %Q!SELECT oxp_open(0,'#{@store.get_text_index_path(:full)}');!
          end
          if (required_text_indicies & Clause::TEXTIDX_FIELDS) == Clause::TEXTIDX_FIELDS
            sql << %Q!SELECT oxp_open(1,'#{@store.get_text_index_path(:fields)}');!
          end
          # Disable the relevancy tracking when it's not needed
          if required_text_indicies != 0 && sort_by != :relevance
            sql << 'SELECT oxp_disable_relevancy();'
          end
          # Append query SQL then execute -- that create_sql() may call into plugins for restriction
          # labels if they're not cached, which could do more queries, so everything has to be executed
          # as one block of SQL.
          sql << create_sql(results, sort_by, options)
          data = db.exec(sql)
        ensure
          # Clear any results in the Xapian interface
          db.perform('SELECT oxp_reset()')
        end
      end

      # Results may or may not include the ids
      ids = nil
      objects = nil

      # Filtering may change the array of results to iterate over
      filtered_data = data

      # Collect type counts, if they've been requested, and filter by type if needed
      # TODO: More optimal way of filtering by type with type counts in KObjectStore queries
      type_counts = nil
      unfiltered_count = nil
      if options[:with_type_counts]
        tfilter = nil
        fdata = nil
        if options.has_key?(:type_filter)
          type_filter = options[:type_filter]
          type_filter = [type_filter] unless type_filter.class == Array
          schema = @store.schema
          tfilter = if options[:type_filter_kind] == :with_subtypes
            type_filter.map { |objref| schema.type_descriptor(objref)._obj_ids_including_child_types(schema) } .flatten
          else
            type_filter.map { |objref| objref.obj_id }
          end
          tfilter.compact!
          if tfilter.empty?
            tfilter = nil
          else
            fdata = Array.new
          end
        end
        # Iterative over results
        col = data.num_fields - 1
        col -= 1 if sort_by == :relevance
        type_counts = Hash.new(0) # default zero for += 1
        data.each do |row|
          t = row[col].to_i
          type_counts[t] += 1
          # If filtering by type, get count and store
          if tfilter != nil && tfilter.include?(t)
            fdata << row
          end
        end
        if tfilter != nil
          # Use filtered data
          filtered_data = fdata
          # Get unfiltered counts
          unfiltered_count = 0
          type_counts.each_value {|c| unfiltered_count += c}
        end
      end

      # NOTE: Results below may have a type_object_id and/or relevance column appended
      if results == :all
        # rows are (id,object) -- id is not used, but has to be there for the SQL to work
        objects = []
        filtered_data.each do |row|
          objects << KObjectStore._deserialize_object(row[1], row[2])
        end
      else
        # rows are (id)
        ids = []
        filtered_data.each do |row|
          ids << row[0].to_i
        end
      end

      Results.new(@store, ids, objects, type_counts, unfiltered_count)
    end

    # ----------------------------------------------------------------------------------------------------
    #   COUNT MATCHES FROM QUERY WITHOUT PERFORMING IT
    # ----------------------------------------------------------------------------------------------------

    def count_matches
      # TODO: Implement this properly, without having to load all the results into memory then discard them
      execute(:reference,:any).length
    end

    # ----------------------------------------------------------------------------------------------------
    #   SQL GENERATION
    # ----------------------------------------------------------------------------------------------------

    def create_sql(results, sort_by, options)
      # Generate the subquery which selects the IDs for the root SQL query
      ids_subquery = generate_subquery(self, @store)
      if @constraints_container != nil && !(@constraints_container.empty?) && !(options[:ignore_constraints_continer])
        # Add in the contraints
        ids_subquery = "(#{ids_subquery} INTERSECT #{@constraints_container.generate_subquery(self, @store)})"
      end

      # Which fields are required, and how do we sort?
      fields = _fields_for(results, options)

      # Ordering
      group_by = ''
      sort_spec = nil
      tbl_extra = ''
      if sort_by == :relevance
        # Check it's possible to order by relevance!
        unless can_order_by_relevance?
          sort_by = :date
        else
          # Generate extra SQL parts for relevancy ranking
          fields = fields.dup
          fields << ",type_object_id"
          group_by = ' GROUP BY '+fields
          fields << ",oxp_relevancy(o#{tbl_extra}.id)*#{store._db_schema_name}.os_type_relevancy(o#{tbl_extra}.type_object_id) AS relevance"
        end
      elsif sort_by.is_a?(FieldSorter)
        # Pluggable sorters
        if sort_by.needs_group_by?
          group_by = ' GROUP BY '+fields
        end
        fields = "#{fields}#{sort_by.fields_extra}"
        tbl_extra = sort_by.table_definition_extra(@store)
        sort_spec = sort_by.sort_spec
      end

      # Generate sort spec now in case :relevance was changed to :date
      sort_spec = _sort_spec_for(sort_by) if sort_spec == nil

      "SELECT #{fields} FROM #{@store._db_schema_name}.os_objects AS o#{tbl_extra} WHERE o.id IN #{ids_subquery}#{label_filter_clause}#{time_sub_clause}#{group_by} ORDER BY #{sort_spec}#{(@offset_start != nil) ? " OFFSET  #{@offset_start}" : ''}#{(@maximum_results != nil) ? " LIMIT #{@maximum_results}" : ''}"
    end

    def label_filter_clause
      @label_filter_clause ||= begin
        # Permissions and filter by labels
        label_filter_sql = ''
        # Wrap the exclusions up in the permissions SQL clause
        user_permissions = KObjectStore.user_permissions
        if user_permissions
          label_filter_sql = " AND #{user_permissions.sql_for_read_query_filter("labels", @exclude_labels)}"
        else 
          unless @exclude_labels.empty?
            label_filter_sql = "AND (NOT labels && '{#{@exclude_labels.map { |l| l.to_i } .uniq.sort.join(',')}}'::int[])"
          end
        end
        if @label_constraints
          # Use @> not && because must match *all* of them
          label_filter_sql = "#{label_filter_sql} AND (labels @> '{#{@label_constraints.map { |l| l.to_i } .join(',')}}'::int[])"
        end
        label_filter_sql
      end
    end

    def _fields_for(results, options)
      fields = (results == :all) ? 'o.id,o.object,labels' : 'o.id'
      # Need to collect types?
      fields = "#{fields},o.type_object_id" if options[:with_type_counts]
      fields
    end

    def _sort_spec_for(sort_by)
      case sort_by
        when :relevance; 'relevance DESC,'
        when :date; 'o.creation_time DESC,'
        when :date_asc; 'o.creation_time,'
        when :title; 'o.sortas_title,'
        when :title_desc; 'o.sortas_title DESC,'
        when :any; ''
        else raise "Unknown sort_by '#{sort_by}'"
      end + 'o.id DESC'
    end
  end

  # ----------------------------------------------------------------------------------------------------
  #   RESULTS OBJECT
  # ----------------------------------------------------------------------------------------------------

  class Results
    include Java::OrgHaploJsinterfaceApp::AppQueryResults

    include Enumerable

    # Maximum number of objects to load in a chunk
    CHUNK_LOAD_SIZE = 128

    # Will always get ids or objects (or both), with optional objrefs
    def initialize(store, ids, objects, type_counts, unfiltered_count)
      @store = store
      @ids = ids
      @objects = objects
      @type_counts = type_counts
      @unfiltered_count = unfiltered_count if unfiltered_count != nil
      @objects_complete = (objects != nil)
    end

    def type_counts
      @type_counts_processed ||= begin
        raise "type_counts not calculated for these results" if @type_counts == nil
        c = Hash.new
        @type_counts.each do |dbid,count|
          if dbid != 0
            c[KObjRef.new(dbid)] = count
          end
        end
        c
      end
    end

    def unfiltered_count
      @unfiltered_count || length
    end

    def length
      if @objects != nil then @objects.length else @ids.length end
    end

    # Returns a full KObject
    def [](index)
      raise "Query result requested out of range" if index < 0 || index >= length
      @objects ||= Array.new(@ids.length, nil) # init to same size as ids
      obj = @objects[index]
      if obj == nil
        KApp.with_pg_database do |db|
          data = db.exec("SELECT object,labels FROM #{@store._db_schema_name}.os_objects WHERE id=#{@ids[index]}")
          raise "Bad search results" if data.length != 1
          obj = KObjectStore._deserialize_object(data.first[0], data.first[1])
        end
        @objects[index] = obj
      end
      obj
    end
    alias jsGet []

    # Makes sure a range of objects is loaded
    def ensure_range_loaded(start_index, end_index)
      return if @objects_complete
      @objects ||= Array.new(@ids.length, nil) # init to same size as ids
      start_index = 0 if start_index < 0
      end_index = 0 if end_index < 0
      l = @ids.length
      return if l == 0
      start_index = l - 1 if start_index >= l
      end_index = l - 1 if end_index >= l
      return if end_index < start_index

      KApp.with_pg_database do |db|

        i = start_index
        needed = Array.new
        lookup = Hash.new
        while i <= end_index
          if @objects[i] == nil
            needed << @ids[i]
            lookup[@ids[i]] = i
          end

          if needed.length >= CHUNK_LOAD_SIZE || (i == end_index && needed.length > 0)
            data = db.exec("SELECT id,object,labels FROM #{@store._db_schema_name}.os_objects WHERE id IN (#{needed.join(',')})")
            raise "Unexpected load quantity" if data.length != needed.length
            data.each do |row|
              @objects[lookup[row[0].to_i]] = KObjectStore._deserialize_object(row[1],row[2])
            end
            needed.clear
            lookup.clear
          end

          i += 1
        end
      end

      @objects_complete if start_index == 0 && end_index == (@objects.length - 1)
    end

    # Returns the KObjRef of the object at that index
    def objref(index)
      if @ids != nil
        KObjRef.new(@ids[index])
      else
        self[index].objref
      end
    end

    # For Enumerable
    def each
      unless @objects_complete
        ensure_range_loaded(0,@ids.length - 1)
        @objects_complete = true
      end
      @objects.each do |o|
        yield o
      end
    end
  end

  # ----------------------------------------------------------------------------------------------------
  #   CLAUSE IMPLEMENTATIONS
  # ----------------------------------------------------------------------------------------------------

  # Base class for clauses
  class Clause
    include Java::OrgHaploJsinterfaceApp::AppQueryClause

    def initialize(parent, desc = nil, qualifier = nil)
      @parent = parent
      @desc = desc if desc != nil
      @qualifier = qualifier if qualifier != nil
    end
    TEXTIDX_FULL    = 1
    TEXTIDX_FIELDS  = 2
    def collect_required_textidx(input_mask)
      input_mask    # don't change the mask in the base class
    end
    def collect_words_for_summary_highlighting(into_array)
      # do nothing
    end
    def generate_subquery(query, store)
      raise "generate_subquery not implemented in #{self.class}"
    end
    def store
      if @store != nil
        @store
      elsif @parent != nil
        @parent.store
      else
        nil
      end
    end

    def label_filter_clause
      if @parent
        @parent.label_filter_clause
      else
        raise "Not implemented in base Clause class"
      end
    end

    def time_sub_clause
      c = ''.dup
      c << " AND creation_time >= #{PGconn.time_sql_value(@start_time)}" if @start_time != nil
      c << " AND creation_time < #{PGconn.time_sql_value(@end_time)}" if @end_time != nil
      c << " AND updated_at >= #{PGconn.time_sql_value(@start_time_updated)}" if @start_time_updated != nil
      c << " AND updated_at < #{PGconn.time_sql_value(@end_time_updated)}" if @end_time_updated != nil
      c
    end
    def sub_query_constraints
      user_labels = store.get_viewing_user_labels
      if user_labels == :superuser
        attribute_restriction_sql = ""
      else
        attribute_restriction_sql = " AND (restrictions IS NULL OR restrictions && '{#{user_labels.join(',')}}'::int[])"
      end
      if @desc == nil
        attribute_restriction_sql
      else
        if @qualifier == nil
          " AND attr_desc = #{@desc.to_i} #{attribute_restriction_sql}"
        else
          " AND attr_desc = #{@desc.to_i} AND qualifier = #{@qualifier.to_i} #{attribute_restriction_sql}"
        end
      end
    end
  end

  # ----------------------------------------------------------------------------------------------------
  #   FIELD SORTERS
  # ----------------------------------------------------------------------------------------------------

  class FieldSorter
    def fields_extra
      ''
    end
    def table_definition_extra(store)
      ''
    end
    def needs_group_by?
      false
    end
    def sort_spec
      ''
    end
  end

  class DateFieldSorter < FieldSorter
    def initialize(order = :asc, desc = nil, qualifier = nil)
      @order = order
      @desc = desc
      @qualifier = qualifier
    end
    def fields_extra
      # If there are multiple date fields meeting the specification, use the latest one
      ',MAX(dt_sort.value) AS dt_sort_max'
    end
    def table_definition_extra(store)
      # Use inner join so only the objects which have sortable data are included
      d = " INNER JOIN #{store._db_schema_name}.os_index_datetime AS dt_sort ON dt_sort.id = o.id".dup
      if @desc != nil
        d << " AND dt_sort.attr_desc = #{@desc.to_i}"
        if @qualifier != nil
          d << " AND dt_sort.qualifier = #{@qualifier.to_i}"
        end
      end
      d
    end
    def needs_group_by?
      true
    end
    def sort_spec
      s = 'dt_sort_max'
      s << ' DESC' if @order == :desc
      s
    end
  end

  # ----------------------------------------------------------------------------------------------------
  #   CLAUSE CONTAINERS
  # ----------------------------------------------------------------------------------------------------

  # Containers with combinations
  class ContainerClause < Clause
    def initialize(parent)
      super
      @clauses = []
    end

    def empty?
      @clauses.empty?
    end

    def add_clause(klass)
      c = klass.new(self); @clauses << c; c
    end
    def and; add_clause(AndBoolClause) end
    def or; add_clause(OrBoolClause) end
    def not; add_clause(NotBoolClause) end

    # Make a special container for overall constraints; used for site restrictions
    def constraints_container
      @constraints_container ||= AndBoolClause.new(self)
      @constraints_container
    end

    # constraint is start_time <= object_time < end_time
    # Either end can be nil for unbounded intervals
    def constrain_to_time_interval(start_time, end_time=nil)  # created time
      if (start_time != nil && start_time.class != Time) || (end_time != nil && end_time.class != Time)
        raise "constrain_to_time_interval() must be passed Time objects"
      end
      @start_time = start_time
      @end_time = end_time
    end
    def constrain_to_updated_time_interval(start_time, end_time=nil) # updated time
      if (start_time != nil && start_time.class != Time) || (end_time != nil && end_time.class != Time)
        raise "constrain_to_updated_time_interval() must be passed Time objects"
      end
      @start_time_updated = start_time
      @end_time_updated = end_time
      self
    end

    # Limit the number of results returned
    def maximum_results(maximum_results)
      r = maximum_results.to_i
      if r > 0
        @maximum_results = r
      else
        raise "Bad maximum_results for query"
      end
    end

    # Offset the results returned
    def offset(offset_start)
      if offset_start.instance_of?(Integer) && offset_start >= 0
        @offset_start = offset_start.to_i
      else
        raise "Bad offset_start for query"
      end
    end

    def has_clauses?; @clauses.length > 0 end

    def collect_required_textidx(input_mask)
      # get the sub-clauses to do this
      m = input_mask
      @clauses.each do |c|
        m = c.collect_required_textidx(m)
      end
      m
    end

    def collect_words_for_summary_highlighting(into_array)
      # get the sub-clauses to do this
      @clauses.each do |c|
        c.collect_words_for_summary_highlighting(into_array)
      end
    end

    # Generate SQL
    def generate_subquery(query, store)
      sub = @clauses.map { |c| c.generate_subquery(query, store) }
      return '' if sub.length == 0
      '(' + sub.join(if self.is_a?(OrBoolClause) then ' UNION '
                elsif self.is_a?(NotBoolClause) then ' EXCEPT '
                else ' INTERSECT ' end) + ')'
    end

    # Add clauses to container
    # All the functions return self, so they can be chained neatly
    def free_text(str, desc = nil, qualifier = nil)
      @clauses << FreeTextClause.new(self, str, desc, qualifier)
      self
    end
    # Link to object or it's children
    def link(obj_or_objref, desc = nil, qualifier = nil)
      @clauses << LinkClause.new(self, obj_or_objref, desc, qualifier)
      self
    end
    # Link to the object only
    def link_exact(obj_or_objref, desc = nil, qualifier = nil)
      @clauses << LinkClauseExact.new(self, obj_or_objref, desc, qualifier)
      self
    end
    # Objects which have a field which is linked to any other object (ie has attribute with objref value)
    def link_to_any(desc = nil, qualifier = nil)
      @clauses << LinkToAnyClause.new(self, desc, qualifier)
      self
    end
    # Identifier
    def identifier(ident, desc = nil, qualifier = nil)
      @clauses << IdentifierClause.new(self, ident, desc, qualifier)
      self
    end
    def jsIdentifierReturningValidity(ident, desc, qualifier)
      clause = IdentifierClause.new(self, ident, desc, qualifier)
      @clauses << clause
      clause.is_valid_identifier_clause?
    end
    def any_indentifier_of_type(identifier_type, desc = nil, qualifier = nil)
      @clauses << AnyIdentifierOfTypeClause.new(self, identifier_type, desc, qualifier)
      self
    end
    # Constrain to objects created by a particular user id (NOT a User object, to avoid creating dependecies)
    def created_by_user_id(user_id)
      @clauses << CreatedByUserClause.new(self, user_id)
      self
    end
    # Type clause; ORed. Argument is array of schema types
    def object_types(types)
      @clauses << TypesClause.new(self, types)
      self
    end
    # Exact title (case insensitive) clause
    def exact_title(title)
      @clauses << ExactTitleCaseInsensitiveClause.new(self, title)
      self
    end
    # Dates
    def date_range(date_min, date_max, desc = nil, qualifier = nil)
      @clauses << DateRangeClause.new(self, date_min, date_max, desc, qualifier)
      self
    end
    # Labels
    def any_label(labels)
      @clauses << LabelClause.new(self, labels, :any)
      self
    end
    def all_labels(labels)
      @clauses << LabelClause.new(self, labels, :all)
      self
    end
    # Special purpose
    def match_nothing()
      @clauses << MatchNothingClause.new(self)
      self
    end

    # Linkage to sub-query
    # These aren't like the methods above, because it returns the clause itself.
    # The caller needs to have access to the object to use it properly.
    # link_type => :exact (direct link) or :hierarchical (link to children as well)
    def add_linked_to_subquery(link_type, desc = nil, qualifier = nil)
      clause = LinkedToSubqueryClause.new(self, link_type, desc, qualifier)
      @clauses << clause
      clause
    end
    def add_linked_from_subquery(desc = nil, qualifier = nil)
      clause = LinkedFromSubqueryClause.new(self, desc, qualifier)
      @clauses << clause
      clause
    end

    # JavaScript interface (boolean hierarchialLink)
    def jsAddLinkedToSubquery(hierarchialLink, desc, qual)
      add_linked_to_subquery(hierarchialLink ? :hierarchical : :exact, desc, qual).subquery_container
    end
    def jsAddLinkedFromSubquery(desc, qual)
      add_linked_from_subquery(desc, qual).subquery_container
    end
  end

  # Boolean operations
  class AndBoolClause < ContainerClause
    def initialize(parent); super end
  end

  class OrBoolClause < ContainerClause
    def initialize(parent); super end
  end

  class NotBoolClause < ContainerClause
    def initialize(parent); super end
    def generate_subquery(query, store)
      if @clauses.length < 2
        raise JavaScriptAPIError, "not() query clauses must have at least two sub-clauses."
      end
      super
    end
  end

  # ----------------------------------------------------------------------------------------------------
  #   IMPLEMENTATIONS
  # ----------------------------------------------------------------------------------------------------

  # Actual implementation of queries
  class QueryAnd < AndBoolClause
    include Query
    def initialize(store)
      super(nil)
      @store = store
    end
  end
  class QueryOr < OrBoolClause
    include Query
    def initialize(store)
      super(nil)
      @store = store
    end
  end

  # ----------------------------------------------------------------------------------------------------
  #   FREE-TEXT CLAUSE
  # ----------------------------------------------------------------------------------------------------

  # info = text or
  #   [:terms, [terms, ...]]
  #   [:phrase, :stemmed or :exact, [terms, ...]]
  #   [:proximity, distance, [term1, term2]]

  class FreeTextClause < Clause
    def initialize(parent, info, desc, qualifier)
      super(parent, desc, qualifier)
      if info.class != Array
        # Convert a KQuery style token - special process for truncated terms with * suffix
        info = [:terms, KTextAnalyser.text_to_terms(info,true).strip.split(' ')]
      end

      # Basic check on types
      case info.first
      when :terms, :phrase, :proximity
        # OK!
      else
        raise "Bad specification to FreeTextClause"
      end
      @info = info
    end

    def collect_required_textidx(input_mask)
      # Use full index if no desc/qual specified, or the fields index if it's needed
      input_mask | ((@desc == nil && @qualifier == nil) ? TEXTIDX_FULL : TEXTIDX_FIELDS)
    end

    def collect_words_for_summary_highlighting(into_array)
      # Collect together the normalised text from the terms
      @info.last.each do |t|
        into_array << $1 if t =~ /\A([^:]+):/
      end
    end

    def generate_subquery(query, store)
      labels = store.get_viewing_user_labels
      sql =
        if @desc == nil && @qualifier == nil
          # Use full index as field not specified
          "(SELECT oxp_simple_query(0, #{PGconn.quote(make_oxp_search_query(@info))}, #{PGconn.quote(make_oxp_search_prefixes(labels,'',store,true))}))"
        else
          # Use fields index
          prefix = if @qualifier == nil
            "#{(@desc || 0).to_s(36)}:"
          else
            "#{(@desc || 0).to_s(36)}_#{@qualifier.to_s(36)}:"
          end
          "(SELECT oxp_simple_query(1, #{PGconn.quote(make_oxp_search_query(@info))}, #{PGconn.quote(make_oxp_search_prefixes(labels,prefix,store,false))}))"
        end
      sql
    end

  private

    def make_oxp_search_query(info)
      basic_prefix = ''
      use_stemmed = true
      join_string = ' '
      quoting = ''
      # Work out what needs to be done for the various types of input
      case info.first
      when :terms
        # Nothing special
      when :phrase
        quoting = '"'
        if info[1] == :exact
          use_stemmed = false
          basic_prefix = '_'  # need to use full word index
        end
      when :proximity
        join_string = " ADJ/#{info[1]} "
      end
      # Map the terms into oxp query terms
      x = info.last.map do |w|
        raise "Bad term" unless w =~ /\A([^:]+):(.+?)(\*?)\z/
        us = use_stemmed
        pr = basic_prefix
        if $3 != nil && !$3.empty?
          # Truncated search term - force unstemmed and set prefix
          us = true
          pr = '_'
        end
        "#{pr}#{us ? $2 : $1}#{$3}"
      end
      quoting + x.join(join_string) + quoting
    end

    def make_oxp_search_prefixes(labels, prefix, store, is_full_index)
      if prefix != ''
        result = [prefix] # Unlabelled prefix
      else
        result = is_full_index ? ["#"] : []
      end

      if labels == :superuser
        labels = store.get_all_restriction_labels
      end
      labels.each do |label|
        result << '#' + KObjRef.new(label.to_i).to_presentation + '#' + prefix
      end
      return result.join(',')
    end
  end

  # ----------------------------------------------------------------------------------------------------
  #   OTHER CLAUSES
  # ----------------------------------------------------------------------------------------------------

  class LinkClause < Clause
    def initialize(parent, obj_or_objref, desc, qualifier)
      super(parent, desc, qualifier)
      @obj_or_objref = obj_or_objref
    end

    def generate_subquery(query, store)
      objref = ((@obj_or_objref.class == KObject) ? @obj_or_objref.objref : @obj_or_objref)
      sqc = sub_query_constraints
      "(SELECT id FROM #{store._db_schema_name}.os_index_link WHERE value @> ARRAY[#{objref.obj_id.to_i}]#{sqc})"
    end
  end

  class LinkClauseExact < Clause
    def initialize(parent, obj_or_objref, desc, qualifier)
      super(parent, desc, qualifier)
      @objref = (obj_or_objref.class == KObject) ? obj_or_objref.objref : obj_or_objref
    end

    def generate_subquery(query, store)
      sqc = sub_query_constraints
      "(SELECT id FROM #{store._db_schema_name}.os_index_link WHERE object_id=#{@objref.obj_id}#{sqc})"
    end
  end

  class LinkToAnyClause < Clause
    def initialize(parent, desc, qualifier)
      super(parent, desc, qualifier)
    end

    def generate_subquery(query, store)
      if @desc == nil
        # Must have a desc, otherwise it doesn't mean anything. If one is missing, return nothing
        "(SELECT id FROM #{store._db_schema_name}.os_index_link WHERE false)"
      else
        sqc = sub_query_constraints
        # Use 'true' because the sql will start with AND
        "(SELECT id FROM #{store._db_schema_name}.os_index_link WHERE true #{sqc})"
      end
    end
  end

  class IdentifierClause < Clause
    def initialize(parent, identifier, desc, qualifier)
      super(parent, desc, qualifier)
      @identifier = identifier
      @identifier_index_str = @identifier.to_identifier_index_str()
    end
    def is_valid_identifier_clause?
      !!(@identifier_index_str)
    end
    def generate_subquery(query, store)
      unless @identifier_index_str
        raise "Object passed to identifier query clause is not an identifier"
      end
      sqc = sub_query_constraints
      # Use output of to_identifier_index_str() on identifier, to match the string which goes in the index
      "(SELECT id FROM #{store._db_schema_name}.os_index_identifier WHERE identifier_type=#{@identifier.k_typecode} AND value=#{PGconn.quote(@identifier_index_str)}#{sqc})"
    end
  end

  class AnyIdentifierOfTypeClause < Clause
    def initialize(parent, identifier_type, desc, qualifier)
      super(parent, desc, qualifier)
      @identifier_type = identifier_type.to_i
    end
    def generate_subquery(query, store)
      sqc = sub_query_constraints
      "(SELECT id FROM #{store._db_schema_name}.os_index_identifier WHERE identifier_type=#{@identifier_type}#{sqc})"
    end
  end

  # Only allow searching by created_by because last modified is a bit unpredictable and won't really do anything useful.
  class CreatedByUserClause < Clause
    def initialize(parent, user_id)
      super(parent)
      @user_id = user_id.to_i
    end
    def generate_subquery(query, store)
      # TODO: Query SQL generation needs more efficient way of implementing clause created by user constraints
      "(SELECT id FROM #{store._db_schema_name}.os_objects WHERE created_by=#{@user_id})"
    end
  end

  class TypesClause < Clause
    def initialize(parent, types)
      super(parent)
      @types = types
    end
    def generate_subquery(query, store)
      type_obj_ids = Array.new
      @types.each do |t|
        t = store.schema.type_descriptor(t) if t.class == KObjRef
        type_obj_ids.concat(t._obj_ids_including_child_types(store.schema))
      end
      type_obj_ids.uniq!
      if type_obj_ids.length == 1
        "(SELECT id FROM #{store._db_schema_name}.os_index_link WHERE object_id = #{type_obj_ids.first} AND attr_desc = #{KConstants::A_TYPE})"
      else
        "(SELECT id FROM #{store._db_schema_name}.os_index_link WHERE object_id IN (#{type_obj_ids.join(',')}) AND attr_desc = #{KConstants::A_TYPE})"
      end
    end
  end

  # Base class for linked to/from clauses
  class LinkedSubqueryClause < Clause
    attr_reader :subquery_container
    def initialize(parent, desc = nil, qualifier = nil)
      super(parent, desc, qualifier)
      @subquery_container = AndBoolClause.new(self)
    end
    def collect_required_textidx(input_mask)
      # Include the text indicies the subquery requires
      @subquery_container.collect_required_textidx(input_mask)
    end
    def generate_subquery(query, store)
      if @subquery_container.empty?
        "(SELECT 1 WHERE true=false)" # match nothing, not nice but it'll avoid issues later
      else
        subquery_sql = @subquery_container.generate_subquery(query, store)
        id_col, linked_col, where_sql = generate_subquery_parts_non_empty(subquery_sql)
        lfc = label_filter_clause
        tables = if lfc.empty?
          "#{store._db_schema_name}.os_index_link"
        else
          # TODO: Could Postgres views be used to make this cleaner/faster? (materialised if necessary)
          "(SELECT os_index_link.*, os_objects.labels FROM #{store._db_schema_name}.os_index_link LEFT JOIN #{store._db_schema_name}.os_objects ON os_index_link.#{linked_col}=os_objects.id) AS os_index_link"
        end
        "(SELECT #{id_col} FROM #{tables} WHERE #{where_sql}#{lfc}#{sub_query_constraints})"
      end
    end
  end

  # Perform the sub-query. Find all objects which link to any of the results, possibly with a given desc/qualifier.
  class LinkedToSubqueryClause < LinkedSubqueryClause
    def initialize(parent, link_type, desc = nil, qualifier = nil)
      super(parent, desc, qualifier)
      @link_type = link_type
    end
    def generate_subquery_parts_non_empty(subquery_sql)
      linkage = case @link_type
      when :exact
        "object_id IN "
      when :hierarchical
        "value && ARRAY"
      else
        raise "Bad link_type for LinkedToSubqueryClause"
      end
      ['id', 'object_id', "#{linkage}(#{subquery_sql})"]
    end
  end

  # Perform the sub-query. Find all objects which any of the results contains a link to, possibly with a given desc/qualifier.
  class LinkedFromSubqueryClause < LinkedSubqueryClause
    def generate_subquery_parts_non_empty(subquery_sql)
      ['object_id', 'id', "id IN (#{subquery_sql})"]
    end
  end

  class ExactTitleCaseInsensitiveClause < Clause
    def initialize(parent, title) # don't have desc, qualifier because these make no sense for this clause
      super(parent)
      @title = title
    end
    def generate_subquery(query, store)
      sqc = sub_query_constraints
      "(SELECT id FROM #{store._db_schema_name}.os_objects WHERE sortas_title=#{PGconn.quote(KTextAnalyser.sort_as_normalise(@title))}#{sqc})"
    end
  end

  class DateRangeClause < Clause
    def initialize(parent, date_min, date_max, desc = nil, qualifier = nil)
      super(parent, desc, qualifier)
      @date_min = date_min
      @date_max = date_max
      raise "At least one date must be specified" if date_min == nil && date_max == nil
      raise "DateRangeClause min value must be Time object" unless @date_min.nil? || @date_min.kind_of?(Time)
      raise "DateRangeClause max value must be Time object" unless @date_max.nil? || @date_max.kind_of?(Time)
    end
    def generate_subquery(query, store)
      sqc = sub_query_constraints
      where_clause = if @date_min != nil && @date_max != nil
        # Range (make sure the ranges overlap)
        "(value, value2) OVERLAPS (TIMESTAMP #{PGconn.time_sql_value(@date_min)}, TIMESTAMP #{PGconn.time_sql_value(@date_max)})"
      elsif @date_min != nil
        # Minimum (compare to latest value of the range)
        "value2 > TIMESTAMP #{PGconn.time_sql_value(@date_min)}"
      elsif @date_max != nil
        # Maximum (compare to earliest value of the range)
        "value < TIMESTAMP #{PGconn.time_sql_value(@date_max)}"
      else
        raise "Logic error in DateRangeClause"
      end
      "(SELECT id FROM #{store._db_schema_name}.os_index_datetime WHERE #{where_clause}#{sqc})"
    end
  end

  class LabelClause < Clause
    def initialize(parent, labels, operation)
      super(parent, nil, nil)
      raise "No labels" if labels.empty?
      @labels = labels
      @operation = case operation
        when :any; "&&"
        when :all; "@>"
        else; raise "Unknown operation for LabelClause #{operation}"
      end
    end
    def generate_subquery(query, store)
      "(SELECT id FROM #{store._db_schema_name}.os_objects WHERE labels #{@operation} '{#{@labels.map { |l| l.to_i } .uniq.sort.join(',')}}'::int[])"
    end
  end

  class MatchNothingClause < Clause
    def initialize(parent)
      super(parent, nil, nil)
    end
    def generate_subquery(query, store)
      "(SELECT id FROM #{store._db_schema_name}.os_objects WHERE false)"
    end
  end
end
