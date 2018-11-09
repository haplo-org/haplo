# coding: utf-8

# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Use KQuery.from_string() to parse search strings

class KQuery
  attr_reader :parse_tree
  attr_reader :flags

  def self.from_string(query_string, schema = KObjectStore.schema)
    KQuery.new(query_string, schema)
  end

  def initialize(query_string, schema = KObjectStore.schema)
    @parse_tree, @flags = parse(query_string, schema)
  end

  # ---------------------------------------------------------------------
  #
  # Format: @parse_tree is a TOKEN, which is one of:
  #
  # [:terms, [TERM, ...]]
  #    Query terms, normalised, stemmed, and may have * to mark truncation
  #    Implied ANDing of all terms
  #
  # [:phrase, :exact | :stemmed, [TERM, ...]]
  #    Second entry is 'style', whether the items are exact or stemmed
  #
  # [:proximity, DISTANCE, [TERM, TERM]]
  #    DISTANCE = integer distance
  #
  # [:machine, String]
  #    String contained the unparsed machine entry
  #
  # [:constraint, CONSTRAINT_INFO, [TERM_TOKENS, ...]]
  #    A query constrainted to an attribute
  #
  # [:types, [KObjRef, ...], rejects]
  #    Objects of a particular type, plus a string containing anything which was rejected
  #
  # [:datetime, CONSTRAINT_INFO, DATES]
  #    DATES is an array of nil or [YYYY, MM, DD, hh, mm] as ints where hh & mm are optional
  #    if 1 element, search for a specific date
  #    if 2 elements, date range, unbounded at that end if an entry is nil
  #
  # [:link_to, CONSTRAINT_INFO, [TOKEN, ...]]
  # [:link_from, CONSTRAINT_INFO, [TOKEN, ...]]
  #    Objects linked to/from a query described contained tokens, treated as an AND container
  #
  # [:container, OPERATOR, [TOKEN, ...]]
  #    Contains other terms, joined by the operation specified by OPERATOR.
  #    If the OPERATOR != [:and], there will be exactly two TOKENs in the array.
  #
  #
  # NOTE: There is an intermediate token type, :term, which never appears in the final output.
  #
  #
  #
  # where:
  #
  #    TOKEN is a token, as above
  #
  #    TERM_TOKENS is a token of type :terms, :phrase, or :proximity
  #
  #    TERM is a string of <normalised text entered>:<stemmed version>[*]
  #       * - if user entered, indicated a truncated search
  #
  #    OPERATOR is an operator, plus details.
  #       [:and], [:or], [:not]
  #
  #    CONSTRAINT_INFO is info on a constraint:
  #       [a_name, q_name, desc, qual, a_kind, typecode, c_errors]
  #       a_name => attribute name, as entered
  #       q_name => qualified name, as entered
  #       desc, qual => decoded a_name and q_name
  #       a_kind => :attr or :alias, depending on attribute definition
  #       typecode => typecode of attribute, defaults to T_TEXT
  #       c_errors => any errors which might be displayed to the user as a result of parsing this constraint
  #

  # ---------------------------------------------------------------------
  # Is query empty? (for checking whether to bother with a search)

  def empty?
    ! check_for_content(@parse_tree)
  end

  def check_for_content(a)
    case a.first
    when :container
      r = false
      a.last.each do |token|
        r = true if check_for_content(token)
      end
      r
    when :phrase, :terms, :proximity, :datetime
      ! a.last.empty?
    when :constraint, :link_to, :link_from
      check_for_content [:container, [:and], a.last]
    when :machine
      true
    when :types
      kind, types, rejects = a
      # If types.empty? then rejects will be used as a simple text query
      ! (types.empty? && rejects.empty?)
    else
      false
    end
  end

  # ---------------------------------------------------------------------
  # Build a query object for KObjectStore

  def add_query_to(q, errors)
    add_query_to_t q, @parse_tree, q.store, errors
  end

  def add_query_to_t(q, token, store, errors)

    kind = token.first

    case kind
    when :terms, :phrase, :proximity
      q.free_text(token)

    when :machine
      add_machine_element_to(q, token, store, errors)

    when :constraint
      add_constraint_to(q, token, store, errors)

    when :types
      add_types_to(q, token, store, errors)

    when :datetime
      add_datetime_to(q, token, store, errors)

    when :link_to
      kind, c_info, contained = token
      a_name, q_name, desc, qual, a_kind, typecode, c_errors = c_info
      q, desc, aliased_descriptor = add_handle_aliases(q, c_info, store.schema)
      errors.concat(c_errors)
      linked_to_link_type, link_types = link_type_for_linked_to_subquery(typecode, desc, aliased_descriptor, store)
      subquery = q.add_linked_to_subquery(linked_to_link_type, desc, qual).subquery_container
      add_query_to_t(subquery, [:container, [:and], contained], store, errors)

    when :link_from
      kind, c_info, contained = token
      a_name, q_name, desc, qual, a_kind, typecode, c_errors = c_info
      q, desc, aliased_descriptor = add_handle_aliases(q, c_info, store.schema)
      errors.concat(c_errors)
      subquery = q.add_linked_from_subquery(desc, qual).subquery_container
      add_query_to_t(subquery, [:container, [:and], contained], store, errors)

    when :container
      # Decode the container
      kind, operator, contained = token
      raise "Bad parse tree" if kind != :container
      op_kind = operator.first

      # Make the appropraite container
      subquery = q.send op_kind

      # Add the contained terms
      is_and = (op_kind == :and)
      gathered_terms = Array.new
      contained.each do |t|
        if is_and && t.first == :terms
          gathered_terms << t
        else
          add_query_to_t(subquery, t, store, errors)
        end
      end

      # Add the gathered terms into one query (:and containers only)
      unless gathered_terms.empty?
        qterms = gathered_terms.map { |t| t.last } .flatten
        subquery.free_text([:terms, qterms])
      end

    else
      raise "Unexpected kind of token"
    end

  end

  def add_constraint_to(q, token, store, errors)
    # Decode token, lookup names of attribute
    kind, c_info, constrained = token
    a_name, q_name, desc, qual, a_kind, typecode, c_errors = c_info

    # Append errors
    errors.concat(c_errors)

    # Handle aliases?
    q, desc, aliased_descriptor = add_handle_aliases(q, c_info, store.schema)

    # Make a container for containing all the constrained stuff
    text_clause = q.and

    # And then add all the constrained items
    constrained.each { |t| text_clause.free_text(t, desc, qual) }
  end

  def link_type_for_linked_to_subquery(typecode, desc, aliased_descriptor, store)
    linked_to_link_type = :exact
    link_types = []
    if desc != nil && typecode == KConstants::T_OBJREF
      # Get attribute descriptor
      schema = store.schema
      ad = (aliased_descriptor || schema.attribute_descriptor(desc))
      link_types = ad.control_by_types
      # Work out which kind of link should be used in the subquery - if any of the types are hierarchical, use a hierarchical link
      linked_to_link_type = :exact
      link_types.each do |typeobjref|
        linked_td = schema.type_descriptor(typeobjref)
        linked_to_link_type = :hierarchical if linked_td != nil && linked_td.is_hierarchical?
      end
    end
    [linked_to_link_type, link_types]
  end

  def add_types_to(q, token, store, errors)
    kind, types, rejects = token
    errors << "There aren't any types defined for #{rejects}" unless rejects.empty?
    if types.empty?
      # Try a free-text search instead
      # TODO: Handle no valid types in a type: constraint better; the problem comes in NULL queries where specifying an invalid type causes it to have an empty query
      q.free_text rejects
    else
      q.object_types(types)
    end
  end

  def add_datetime_to(q, token, store, errors)
    kind, c_info, dates = token
    a_name, q_name, desc, qual, a_kind, typecode, c_errors = c_info
    # Handle aliased fields
    q, desc, aliased_descriptor = add_handle_aliases(q, c_info, store.schema)
    # Turn the dates into date objects
    dx = dates.map do |x|
      if x == nil
        nil
      else
        if x.length == 3
          y, m, d = x
          [:day, DateTime.new(y, m, d)]
        elsif x.length == 5
          y, m, d, hh, mm = x
          [:min, DateTime.new(y, m, d, hh, mm)]
        else
          raise "Logic error in date time parsing"
        end
      end
    end
    # Create clause
    if dx.length == 1
      precision, date = dx.first
      q.date_range(date, (precision == :day) ? (date + 1) : (date + Rational(1,3600)), desc, qual)
    else
      # Expand right hand side of range to one day later to work as the user expects
      ignored_precsion, first_date = dx.first
      last_precision, last_date = dx.last
      if last_date != nil && last_precision == :day
        # Minute precisions at end of date ranges should not be extended
        last_date += 1
      end
      q.date_range(first_date, last_date, desc, qual)
    end
  end

  def add_machine_element_to(query, token, store, errors)
    # Text from query
    machine = token.last

    # Type of query?
    type = MACHINE_ELEMENT_TAGS[machine[0]]
    if type == nil
      errors << "Bad type of machine element ##{machine.gsub(/[\<\>]/,'')}#"
      return nil
    end

    # Start building the decoded output
    machine_element = {:type => type, :input => machine}

    # Parse the elements
    machine.split('/').each do |t|
      ttype = MACHINE_ELEMENT_TAGS[t[0]]
      if ttype != nil
        machine_element[ttype] = t[1..(t.length-1)]
      end
    end

    # Get desc and qualifier
    desc = nil
    if machine_element[:desc] != nil
      desc = machine_element[:desc].to_i
    end
    qualifier = nil
    if desc != nil && machine_element[:qualifier] != nil
      qualifier = machine_element[:qualifier].to_i
    end

    # Machine specific clause
    case machine_element[:type]
    when :link
      # Link machine clause
      objref = KObjRef.from_presentation(machine_element[:link])
      if objref != nil
        query.link(objref, desc, qualifier)
      elsif machine_element[:link] == '*'
        query.link_to_any(desc, qualifier)
      end
    when :exact_link
      # Exact link machine clause
      objref = KObjRef.from_presentation(machine_element[:exact_link])
      if objref != nil
        query.link_exact(objref, desc, qualifier)
      end
    when :user
      # User link machine clause
      query.created_by_user_id(machine_element[:user].to_i)
    else
      errors << "Unable to parse machine element ##{machine.gsub(/[\<\>]/,'')}#"
    end
  end

  # Returns the (possibly altered) query clause, desc to query on, nil or the aliased attribute descriptor
  def add_handle_aliases(q, c_info, schema)
    # For returning the aliased descriptor, if it's an alias
    aliased_descriptor = nil
    # Decode the constraint info
    a_name, q_name, desc, qual, a_kind, typecode, c_errors = c_info
    # Desc to return
    query_desc = desc
    # Handle alias?
    if desc != nil && a_kind == :alias
      # Look up the descriptor
      aliased_descriptor = schema.aliased_attribute_descriptor(desc)
      # Set desc to do the query on
      query_desc = aliased_descriptor.alias_of
      # See what types support this alias
      types_using_alias = schema.root_types.map { |t| schema.type_descriptor(t) } .select { |t| t.attributes.include?(desc) }
      unless types_using_alias.empty?
        # Constrain to these types
        q = q.and
        q.object_types(types_using_alias)
        # And make sure a container is returned
        q = q.and
      end
    end
    [q, query_desc, aliased_descriptor]
  end

  # ---------------------------------------------------------------------
  # Make a nice HTML rendition

  def query_as_html(schema)
    query_as_html_t schema, @parse_tree, false
  end

  def query_as_html_t(schema, token, alt)

    kind = token.first

    case kind
    when :terms
      displayable_terms(token.last).join(' ') + ' '

    when :phrase
      kind, style, terms = token
      quote = (style == :stemmed) ? '"' : "'"
      %Q!<i>#{(style == :stemmed) ? nil : 'exact '}phrase</i> #{quote}#{displayable_terms(terms).join(' ')}#{quote}!

    when :proximity
      kind, distance, terms = token
      a, b = terms
      %Q!(#{displayable_terms([a]).first} <i>within #{distance} of</i> #{displayable_terms([b]).first})!

    when :machine
      '<i>#'+token.last+'#</i>'

    when :constraint
      kind, c_info, constrained = token
      # attr-qualifier pairs
      n = desc_qual_names_to_html(schema, c_info)
      %Q!<span class="z__search_explanation_attr_name">#{n} :</span> #{constrained.map { |x| query_as_html_t(schema, x, false) } .join(' ')}!

    when :types
      kind, types, rejects = token
      # TODO: Add icons for types
      %Q!<span class="z__search_explanation_attr_name">Type :</span> #{types.map {|d| schema.type_descriptor(d).printable_name}.join(', ')} <strike>#{rejects}</strike>!

    when :datetime
      kind, c_info, dates = token
      n = desc_qual_names_to_html(schema, c_info)
      n = %Q!<span class="z__search_explanation_attr_name">#{n} :</span> !
      if dates.length == 1
        n << date_to_html(dates.first)
      elsif dates.length == 2
        if dates.first == nil
          n << %Q!<i>before<i> #{date_to_html(dates.last)}!
        elsif dates.last == nil
          n << %Q!<i>after<i> #{date_to_html(dates.first)}!
        else
          n << %Q!#{date_to_html(dates.first)} <i>to</i> #{date_to_html(dates.last)}!
        end
      end
      n

    when :link_to, :link_from
      kind, c_info, contained = token
      n = desc_qual_names_to_html(schema, c_info)
      arrow, text = (kind == :link_to) ? ['&darr;', 'TO'] : ['&uarr;', 'FROM']
      h = %Q!<div class="#{alt ? 'z__search_explanation_box_b' : 'z__search_explanation_box_a'}">!
      h << %Q!<div class="z__search_explanation_linked_to_statement">#{arrow}<div><span>LINKED #{text}!
      h << " BY '#{n}'" unless n.empty?
      h << %Q!</span></div>#{arrow}</div>!
      # Draw the contents as an :and container
      h << query_as_html_t(schema, [:container, [:and], contained], !alt)
      h << '</div>'

    when :container
      style = alt ? 'z__search_explanation_box_b' : 'z__search_explanation_box_a'

      kind, operator, contained = token
      op_kind = operator.first

      j_html = %Q!<div class="z__search_explanation_bool_join"><span>#{op_kind.to_s.upcase}</span></div>!
      if op_kind == :and
        # Some tokens don't get need AND between them
        last = nil
        out = ''
        contained.each do |token|
          if last != nil
            if token_is_and_joinable?(last) && token_is_and_joinable?(token)
              out << ' '
            else
              out << j_html
            end
          end
          out << query_as_html_t(schema, token, alt) # no !
          last = token
        end
        out
      else
        # Other operators do need joining for each element
        %Q!<div class="#{style}">#{contained.map { |e| query_as_html_t(schema, e, !alt) } .join(j_html)}</div>!
      end

    else
      '????'
    end
  end

  def displayable_terms(terms)
    terms.map do |t|
      (t =~ /\A([^:]+):.+?(\*?)\z/) ? "#{$1}#{$2}" : t
    end
  end

  def token_is_and_joinable?(token)
    case token.first
    when :terms, :proximity, :machine
      true
    else
      false
    end
  end

  def desc_qual_names_to_html(schema, c_info)
    a_name, q_name, desc, qual, a_kind, typecode, c_errors = c_info
    n = ''
    if desc != nil
      n << ((a_kind == :attr) ?
        schema.attribute_descriptor(desc).printable_name.text :
        schema.aliased_attribute_descriptor(desc).printable_name.text )
    elsif a_name != nil
      n << "<strike>#{a_name}</strike>"
    end
    if qual != nil
      n << " <i>#{schema.qualifier_descriptor(qual).printable_name.text}</i>"
    elsif q_name != nil
      n << " <i><strike>#{q_name}</strike></i>"
    end
    n
  end

  def date_to_html(date)
    y, m, d = date
    sprintf("%04d-%02d-%02d", y, m, d)
  end

  def collect_words_from(tokens)
    o = Array.new
    tokens.each do |token|
      case token.first
      when :phrase, :proximity, :terms
        token.last.each { |x| o << x }
      when :term
        o << token.last
      end
    end
    o
  end

  # ---------------------------------------------------------------------
  # Reproduce a nice and compact query string

  def minimal_query_string(schema = KObjectStore.schema)
    s = min_query_token(@parse_tree, schema)
    s.gsub(' (','(').gsub(') ',')') # tidy
    @flags.each_key { |f| s += '~'+FLAGS_REVERSE[f] }
    s
  end

  def min_query_token(token, schema)
    kind = token.first
    case kind
    when :terms
      mq_terms_as_text(token.last)

    when :phrase
      kind, style, terms = token
      bracket = (style == :exact) ? "'" : '"'
      "#{bracket}#{mq_terms_as_text(terms)}#{bracket}"

    when :proximity
      kind, distance, terms = token
      a, b = terms
      "#{mq_terms_as_text(a)} _#{distance} #{mq_terms_as_text(b)}"

    when :machine
      "##{token.last}#"

    when :constraint
      kind, c_info, constrained = token
      mq_constraint(c_info) + constrained.map { |t| min_query_token(t, schema) } .join(' ')

    when :types
      kind, types, rejects = token
      if types.empty?
        ''
      else
        "type:#{types.map {|d| schema.type_descriptor(d).printable_name}.join(' ')}"
      end

    when :datetime
      kind, c_info, dates = token
      dx = dates.map do |x|
        if x == nil
          ''
        else
          y, m, d, hh, mm = x
          d = sprintf("%04d-%02d-%02d", y, m, d)
          d << sprintf("T%02d.%02d", hh, mm) if hh != nil
          d
        end
      end
      "#{mq_constraint(c_info)}#{dx.join(' .. ')}"

    when :link_to, :link_from
      kind, c_info, contained = token
      symbol = (kind == :link_to) ? '>' : '<'
      "(#{symbol}#{mq_constraint(c_info, false)}#{symbol} (#{contained.map { |t| min_query_token(t, schema) } .join(' ') }))"

    when :container
      kind, op, contained = token
      op_kind = op.first
      join_name = ((op_kind == :and) ? ' ' : " #{op_kind.to_s.upcase} ")
      "(#{contained.map { |t| min_query_token(t, schema) } .join(join_name) })"

    else
      '????'
    end
  end

  def mq_terms_as_text(*terms)
    terms.flatten.map do |term|
      term =~ /\A([^:]*):.+?(\*?)\z/
      $1 + $2
    end .join(' ')
  end

  def mq_constraint(c_info, with_colon = true)
    a_name, q_name, desc, qual, a_kind, typecode, c_errors = c_info
    n = ''
    if desc != nil
      n << a_name.downcase
      if qual != nil
        n << '/'
        n << q_name.downcase
      end
      n << ':' if with_colon
    end
    n
  end

  # ---------------------------------------------------------------------
  # Constants for query string parsing

  MACHINE_ELEMENT_MARKER = ?#
  MACHINE_ELEMENT_TAGS = {
    ?d => :desc,
    ?q => :qualifier,
    ?t => :tag,
    ?U => :user,
    ?L => :link,
    ?E => :exact_link
  } # if this is changed, make sure R_TOK_MACHINE is updated

  FLAGS = {
    'A' => :include_concept_objects,
    'R' => :include_archived_objects,
    'D' => :deleted_objects_only,
    'S' => :include_structure_objects,
  } # IMPORTANT: Update FLAGS_REGEXP & FLAGS_REVERSE below if you add/remove flags
  FLAGS_REVERSE = {
    :include_concept_objects => 'A',
    :include_archived_objects => 'R',
    :deleted_objects_only => 'D',
    :include_structure_objects => 'S'
  }
  FLAGS_REGEXP = /\s*\~([ARDS])\s*\z/

  OPERATIONS = {
    'and' => :and, '+' => :and,
    'or' => :or, '|' => :or,
    'not' => :not, '!' => :not
  }

  # NOTE: [\p{Word}\p{So}] matchs unicode categories Letter, Mark, Number, Connector_Punctuation, including 0-9A-Za-z_, plus Other Symbols (using \p{So})
  # Sync this with the symbols allowed in Analyser.java, and make sure all occurances are changed.
  # NOTE: Xapian has a slightly different view of what's a word (see is_wordchar() implementation) -- perhaps should patch it to match this view?
  TOK_CONTAINER_START = '('
  TOK_CONTAINER_END   = ')'
  TOK_PHRASE_STEMMED  = '"'
  TOK_PHRASE_EXACT    = "'"
  R_TOK_PROXIMITY     = /\A(.+?)\_(\d+)\_(.+?)\z/
  R_TOK_CONSTRAINT    = /\A([\p{Word}\p{So}-]+)(\/([\p{Word}\p{So}-]*))?:\z/
  R_TOK_LINKAGE_TO    = /\A\>([\p{Word}\p{So}-]+)?(\/([\p{Word}\p{So}-]*))?\>\z/
  R_TOK_LINKAGE_FROM  = /\A\<([\p{Word}\p{So}-]+)?(\/([\p{Word}\p{So}-]*))?\<\z/
  R_TOK_MACHINE       = /\A#([sdqtULE][^#]+)#/

  # ---------------------------------------------------------------------
  # Parsing

  def parse(input, schema)

    # Sort out syntatical stuff
    parse = input.dup
    # Make sure brackets and other operator type stuff have space surrounding
    parse.gsub!(/\s*([\(\)\&\+\|\!])\s*/, ' \1 ')
    # Constraints are in one block
    parse.gsub!(/([\p{Word}\p{So}-]+)\s*:\s*/, ' \1: ')
    parse.gsub!(/([\p{Word}\p{So}-]+)\s*\/\s*([\p{Word}\p{So}-]*):\s*/, ' \1/\2: ')
    # Fix single words in quotes
    parse.gsub!(/(\A|\s+)(['"])([\p{Word}\p{So}]+)(['"])(\s+|\z)/, '\1 \2 \3 \4 \5')
    # Put spaces around quotes, but only if they're start or end quotes
    2.times { parse.gsub!(/((\A|\s+)['"]|['"](\s+|\z))/, ' \1 ') }  # do twice to allow "phrase 1" "phrase 2" to work
    # Linking operators
    parse.gsub!(/\>([^\>]*?)\>/) { " >#{$1.gsub(/\s+/,'')}> " }
    # Proximity operator
    parse.gsub!(/([\p{Word}\p{So}])\s*\_(\d+)_?\s*([\p{Word}\p{So}])/, '\1_\2_\3')
    # Machine queries
    parse.gsub!(/#([^\s#]+?)#/, ' #\1# ')
    # Truncated searches
    parse.gsub!(/([\p{Word}\p{So}])\s*\*+/, '\1*')
    # But delete trunated searches on their own
    parse.gsub!(/\s+\*+/,' ')

    # Pull off the flags
    flags = Hash.new
    while (parse.sub!(FLAGS_REGEXP) { flags[FLAGS[$1]] = true; '' }) != nil; end

    tokens = parse.strip.split(/\s+/)

    in_phrase = nil
    t = Array.new
    tokens.each do |token|
      if in_phrase != nil
        if token == TOK_PHRASE_STEMMED || token == TOK_PHRASE_EXACT
          # Handle silly cases
          if in_phrase.empty?
            t.pop
          elsif in_phrase.length == 1
            t.pop
            t << [:term, in_phrase.first]
          end
          # Unflag being in a phrase
          in_phrase = nil
        else
          # In phrases we don't do any special parsing, so just store the term.
          # Don't allow truncated searches
          in_phrase << token.gsub(/\*+\z/,'')
        end
      else

        if token == TOK_CONTAINER_START
          t << [:start]

        elsif token == TOK_CONTAINER_END
          t << [:end]

        elsif token =~ R_TOK_CONSTRAINT
          t << [:constraint, process_constraints($1, $3, schema), []]

        elsif token =~ R_TOK_LINKAGE_TO
          t << [:link_to, process_constraints($1, $3, schema)]

        elsif token =~ R_TOK_LINKAGE_FROM
          t << [:link_from, process_constraints($1, $3, schema)]

        elsif token =~ R_TOK_PROXIMITY
          t << [:proximity, $2.to_i, [$1, $3]]

        elsif token =~ R_TOK_MACHINE
          t << [:machine, $1]

        elsif (op = OPERATIONS[token.downcase])
          t << [:operator, [op]]

        elsif token == TOK_PHRASE_STEMMED || token == TOK_PHRASE_EXACT
          # Start a phrase
          in_phrase = Array.new
          t << [:phrase, (token == TOK_PHRASE_STEMMED) ? :stemmed : :exact, in_phrase]

        else
          t << [:term, token]

        end

      end
    end
    tokens = t

    # Bundle constraints into the constrained text, fix starts and ends
    in_constraint = nil
    # Fix starts and ends
    n_starts = 0
    n_ends = 0
    t = Array.new
    tokens.each do |token|
      kind = token.first
      n_starts += 1 if kind == :start
      n_ends += 1 if kind == :end
      while n_ends > n_starts
        t.unshift [:start]
        n_starts += 1
      end
      if in_constraint
        if kind == :term || kind == :phrase || kind == :proximity
          in_constraint.last << token
        else
          in_constraint = nil
          # Token is appended below
        end
      end
      # Must start a new if statement so that a constraint following a term/phrase still gets recorded
      if in_constraint == nil
        if kind == :constraint
          in_constraint = token
        end
        t << token
      end
    end
    if n_ends < n_starts
      1.upto(n_starts - n_ends) { t << [:end] }
    elsif n_starts < n_ends
      1.upto(n_ends - n_starts) { t.unshift [:start] }
    end
    tokens = t

    # Expand out constraints which didn't find any terms or phrases to constrain
    t = Array.new
    tokens.each do |token|
      if token.first == :constraint && token.last.empty?
        # Constraint didn't catch anything to constraint, use the field names as straight terms
        kind, c_info, constrained = token
        c_info[0..1].each { |x| t << [:term, x] if x != nil }
      else
        t << token
      end
    end
    tokens = t

    # Create containers from start / end blocks
    t = Array.new
    stack = Array.new
    tokens.each do |token|
      kind = token.first
      if kind == :start
        # Start a new block
        stack << t
        n = Array.new
        t << [:container, [:and], n]
        t = n
      elsif kind == :end
        t = stack.pop
      else
        t << token
      end
    end

    # And from that, build a root token
    root_token = [:container, [:and], t]

    # Go through and push the operators/proximity into the containers
    change_operators_and_links_within root_token

    # Depending on the typecode, some constraints might need to be transformed into something else
    root_token = transform_constraints(root_token, schema)

    # Get rid of useless containers (making sure there's an empty container at the very least)
    # This maximises the change of combining :term tokens into :terms
    root_token = trim_container(root_token) || [:container, [:and], []]

    # Collect together :term tokens into :terms bundles.
    # Do this after everything else has been given the oppourtunity to create term tokens
    root_token = process_terms_in_tokens([root_token]).first

    # Second run at getting rid of useless containers now multiple :term tokens might have turned into single :terms tokens
    root_token = trim_container(root_token) || [:container, [:and], []]

    [root_token, flags]
  end

  def process_constraints(a, q, schema)
    a_name = process_constraint(a)
    q_name = process_constraint(q)
    desc = nil
    qual = nil
    a_kind = :attr
    typecode = KConstants::T_TEXT
    errors = []
    if a_name != nil
      # Descriptor
      desc = schema.attr_desc_by_name(a_name.downcase)
      if desc == nil
        # Try an aliased descriptor?
        desc = schema.aliased_attr_desc_by_name(a_name.downcase)
        if desc != nil
          a_kind = :alias
        else
          # No, not an aliased one either
          errors << "There's no field called '#{a_name}'"
        end
      end
      if desc != nil
        # Find type of field?
        typecode = ((a_kind == :attr) ?
            schema.attribute_descriptor(desc).data_type :
            schema.aliased_attribute_descriptor(desc).data_type)
        # Qualifer
        qual = (q_name == nil) ? nil : schema.qual_desc_by_name(q_name.downcase)
        if q_name != nil && qual == nil
          errors << "There's no qualifier called '#{q_name}'"
        end
      end
    end
    [a_name, q_name, desc, qual, a_kind, typecode, errors]
  end

  def process_constraint(c)
    (c == nil || c.empty?) ? nil : c
  end

  def process_terms_in_tokens(tokens)
    t = Array.new
    # Collect terms together
    tokens.each do |token|
      kind = token.first
      if kind == :term
        n = t.last
        # Create a terms token, or append to previous one
        if n == nil || n.first != :terms
          t << [:terms, [token.last]]
        else
          n.last << token.last
        end
      else
        if kind == :constraint || (kind == :container && token[1].first == :and)
          # Collect together terms constraints and :and containers
          token.push(process_terms_in_tokens(token.pop))
        elsif kind == :container || kind == :link_to || kind == :link_from
          # Otherwise process all the elements without combining them
          token.push(token.pop.map { |e| process_terms_in_tokens([e]).first })
        end
        t << token
      end
    end
    t.each do |token|
      case token.first
      when :terms, :phrase, :proximity
        token.push(process_terms(token.pop))
      end
    end
    t
  end

  def process_terms(terms)
    # Convert to terms, with special support for * denoting truncated query terms
    KTextAnalyser.text_to_terms(terms.join(' '), true).strip.split(/ /)
  end

  def change_operators_and_links_within(container)
    r = 0
    tokens = container.last
    while r < tokens.length
      e = tokens[r]
      kind = e.first
      case kind
      when :container
        change_operators_and_links_within e
      when :operator
        k, operator, info = e
        # if it's first or last, just delete it
        if r == 0 || r >= (tokens.length - 1)
          tokens.delete_at(r)
          r -= 1  # because something was deleted
        else
          tokens.delete_at(r) # remove the operator token
          contained = tokens.slice!(r - 1 .. (tokens.length - 1))
          # Operators other than :and have two items
          if operator.first != :and
            if contained.length > 2
              lhs = contained.shift
              contained = [lhs, [:container, [:and], contained]]
            end
          end
          tokens << [:container, operator, contained]
          r -= 2  # get the container recursively processed next time round, taking into account the deleted objects
        end
      when :link_to, :link_from
        if e.length == 2 # prevent processing this twice in recursive descent, not 100% this is correct fix of "(a >> b) or c"
          # Need to pull everything to the right into this link
          # Will get deleted later if the container is empty
          e << (tokens.slice!(r + 1 .. (tokens.length - 1)) || [])
          # Do go through the stuff just absorbed into this link
          change_operators_and_links_within e
        end
      end
      r += 1
    end
  end

  def transform_constraints(token, schema)
    case token.first
    when :constraint
      kind, c_info, constrained = token
      a_name, q_name, desc, qual, a_kind, typecode, errors = c_info
      if a_name != nil && a_name =~ /\Atypes?\z/i
        # Turn it into a type constraint
        text = collect_words_from(constrained).join(' ').gsub(/[\,\.\*]/,' ').downcase
        types, rejects = schema.types_from_short_names(text)
        # Make the replacement type constraint token
        [:types, types.map { |t| t.objref }, rejects]
      elsif typecode == KConstants::T_DATETIME
        # Turn it into a date constraint, if the dates can be parsed OK
        text = collect_words_from(constrained).join(' ').strip.split(/\s+/)
        dates = Array.new
        range_index = nil
        # Decode dates, and see if there's a range operator
        text.each do |t|
          if t == '..' || t.downcase == 'to'
            range_index = dates.length
          elsif t =~ /(\d\d\d\d)-(\d\d?)-(\d\d?)(T(\d\d?)\S(\d\d?))?/
            # Rather tolerant for now, but check that they're valid date & times by attempting to create a datetime object
            y = $1.to_i; m = $2.to_i; d = $3.to_i
            have_time = ($4 != nil && $4 != '')
            h = ($5 || 0).to_i; mn = ($6 || 0).to_i
            begin
              DateTime.new(y, m, d, h, mn) # checks it's valid
              d = [y, m, d]
              if have_time
                d << h ; d << mn
              end
              dates << d
            rescue => e
              # Ignore exceptions caused by invalid dates
            end
          end
        end
        # Got a valid date?
        looks_promising = (range_index != nil && dates.length > 0)
        if looks_promising && (range_index == 0 && dates.length > 0)
          # Up to date
          [:datetime, c_info, [nil, dates[0]]]
        elsif looks_promising && (range_index == dates.length)
          # After date
          [:datetime, c_info, [dates.last, nil]]
        elsif looks_promising && (range_index > 0 && range_index < dates.length)
          # Range of dates
          [:datetime, c_info, [dates[range_index - 1], dates[range_index]]]
        elsif dates.length > 0
          # Use the first date as a single date
          [:datetime, c_info, [dates.first]]
        else
          # Give up and use the token as a text field
          token
        end
      else
        token
      end

    when :container, :link_to, :link_from
      t = token.dup
      t << t.pop.map { |x| transform_constraints(x, schema) }
    else
      token
    end
  end

  def trim_container(container)
    # Make sure it's actually a container!
    kind = container.first
    return container unless (kind == :container) || (kind == :link_to) || (kind == :link_from)
    # Recurse into containers and links
    tokens = container.pop
    tokens = tokens.map do |token|
      case token.first
      when :container, :link_to, :link_from
        trim_container(token)
      else
        token
      end
    end
    tokens.compact! # remove nils
    # Now return something useful
    if tokens.empty?
      # No tokens, useless branch
      nil
    elsif tokens.length == 1 && (container.first == :container)
      # Only one token in a container (not a link!), so this container is pointless, return the first thing in it
      tokens.first
    else
      # Put the tokens back into container and return it
      container << tokens
      container
    end
  end

end
