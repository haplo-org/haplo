# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class KLabelList
  include Enumerable
  include Java::OrgHaploJsinterfaceApp::AppLabelList

  def initialize(list)
    @list = list.map { |l| l.to_i } .sort.uniq.freeze
    # Check for any nil, 0 or negative IDs. Because it's sorted, only need to check first
    raise "Labels list must not contain nil, 0 or negative IDs, result #{@list.inspect} for new(#{list.inspect})" unless @list.empty? || @list.first > 0
    self.freeze
  end

  def include?(label)
    @list.include?(label.to_i)
  end

  def include_all?(label_list)
    others = label_list._to_internal
    return false if others.empty? # special case
    (@list & others).length == others.length # assume .sort.uniq in initialize
  end

  def each
    @list.each { |l| yield KObjRef.new(l) }
  end

  def [](index)
    raise "Bad index" if index < 0 || index >= @list.length
    KObjRef.new(@list[index.to_i])
  end

  def length
    @list.length
  end

  def empty?
    @list.empty?
  end

  def copy_adding(to_add)
    KLabelList.new(@list + (to_add.map { |l| l.to_i }))
  end

  def copy_removing(to_remove)
    KLabelList.new(@list - (to_remove.map { |l| l.to_i }))
  end

  # Standard operators
  def ==(other)
    other.kind_of?(KLabelList) && other._to_internal == @list
  end
  def eql?(other)
    other.kind_of?(KLabelList) && other._to_internal == @list
  end
  def hash
    @list.hash
  end
  def <=>(other)
    @list <=> other._to_internal
  end

  # For consumers of the API to get access to underlying list
  def _to_internal
    @list
  end

  # SQL intarray support (caller needs to add quotes)
  def _to_sql_value
    "{#{@list.join(',')}}"
  end

  def self._from_sql_value(str)
    raise "Bad SQL value" unless str =~ /\A\{([0-9,]*)\}\z/
    KLabelList.new($1.split(','))
  end

end

# -------------------------------------------------------------------------------------

# Represents changes to a list of labels
class KLabelChanges
  include Java::OrgHaploJsinterfaceApp::AppLabelChanges

  def initialize(add = nil, remove = nil)
    @add = add || []
    @remove = remove || []
  end

  def self.changing(from, to)
    f = from._to_internal
    t = to._to_internal
    KLabelChanges.new(t - f, f - t)
  end

  def add(*labels)
    @add.concat labels.flatten
    self
  end

  def will_add?(label)
    _ll(@add).include?(label.to_i)
  end

  def remove(*labels)
    @remove.concat labels.flatten
    self
  end

  def will_remove?(label)
    _ll(@remove).include?(label.to_i)
  end

  def empty?
    @add.empty? && @remove.empty?
  end

  def change(list)
    KLabelList.new(((list._to_internal + _ll(@add)) .sort.uniq) - _ll(@remove))
  end

  def _sql_expression(expr)
    if @add.empty? && @remove.empty?
      expr
    else
      expr = "((#{expr})+'{#{_ll(@add).join(',')}}'::int[])" unless @add.empty?
      expr = "((#{expr})-'{#{_ll(@remove).join(',')}}'::int[])" unless @remove.empty?
      %Q!uniq(sort_asc(#{expr}))!
    end
  end

  # For JS interface
  def _add_internal; _ll(@add); end
  def _remove_internal; _ll(@remove); end

private
  # Make sure a list is all ints, sorted and no duplicate entries
  def _ll(list)
    list.map { |l| l.to_i } .sort.uniq
  end
end

# -------------------------------------------------------------------------------------

# Base class which says no to everything
class KLabelStatements
  include Java::OrgHaploJsinterfaceApp::AppLabelStatements # required because auto-include when passing to Java breaks if instance is frozen

  def is_simple_statements?
    false # base class doesn't represent a simple statement about rules
  end

  def is_superuser?
    false
  end

  def label_is_allowed?(operation, label)
    false
  end
  def label_is_denied?(operation, label)
    true
  end

  def something_allowed?(operation)
    false
  end

  def allow?(operation, label_list)
    false # base class allows nothing
  end

  def _sql_condition(operation, column, additional_excludes = nil)
    "FALSE" # base class sees nothing
  end

  def ui_display
    []
  end

  # Create labels statements from bitmask storage
  #   bitmasks is array of arrays [label, allow, deny]
  #   operation_bits is array of arrays [operation, bit]
  def self.from_bitmasks(bitmasks, operation_bits)
    allows = {}
    denies = {}
    operation_bits.each do |operation, bit|
      op_allow = []
      op_deny = []
      bitmasks.each do |label_int, allow, deny|
        op_allow << label_int if (allow & bit) == bit
        op_deny  << label_int if (deny  & bit) == bit
      end
      allows[operation] = op_allow.map { |l| l.to_i } .uniq.sort.freeze
      denies[operation] = op_deny .map { |l| l.to_i } .uniq.sort.freeze
    end
    KLabelStatementsOps.new(allows, denies).freeze
  end

  # Make a super-user statements object
  def self.super_user
    KLabelStatementsSuperUser.new.freeze
  end

  # Combine two label statements
  def self.combine(a, b, operation)
    case operation
    when :and, "and"
      KLabelStatementsAnd.new(a, b).freeze
    when :or, "or"
      KLabelStatementsOr.new(a, b).freeze
    else
      raise "Unknown operation #{operation} for combine()"
    end
  end

  # For JS interface
  def jsAllow(o,l); allow?(o.to_sym, l); end # o is checked to be one of the allowed operations by trusted Java code
end

# -------------------------------------------------------------------------------------

class KLabelStatementsOps < KLabelStatements

  # Users of this class should not pass arguments, use statement() or from_bitmasks() instead.
  def initialize(_allow = {}, _deny = {})
    super()
    @allow = _allow
    @deny = _deny
  end

  def is_simple_statements?
    true # represents simpliest form of statements
  end

  def ui_display
    self
  end

  # Sets a statement for a given operation
  def statement(operation, allow_labels, deny_labels)
    raise TypeError, "can't modify a frozen KLabelStatements" if self.frozen?
    raise "operation must be a symbol" unless operation.kind_of?(Symbol)
    @allow[operation] = allow_labels._to_internal
    @deny[operation]  = deny_labels._to_internal
  end

  # Checks if a specific label is in the lists
  def label_is_allowed?(operation, label)
    allow = @allow[operation] || []
    deny = @deny[operation] || []
    allow.include?(label.to_i) && !(deny.include?(label.to_i))
  end
  def label_is_denied?(operation, label)
    deny = @deny[operation] || []
    deny.include?(label.to_i)
  end

  # Checks if there are any labels allowed for an operation
  def something_allowed?(operation)
    ! (@allow[operation] || []).empty?
  end

  # Checks if an operation is allowed for a given label list
  def allow?(operation, label_list)
    labels = label_list._to_internal
    statement_allow = @allow[operation]
    statement_deny = @deny[operation]
    raise "no statement for operation #{operation}" unless statement_allow && statement_deny
    # Labels must contain at least one entry from the allow list, and no entries from the deny list
    !((statement_allow & labels).empty?) && (statement_deny & labels).empty?
  end

  # For building SQL conditions matching operation
  def _sql_condition(operation, column, additional_excludes = nil)
    statement_allow = @allow[operation]
    statement_deny = @deny[operation]
    if additional_excludes
      # Add in any additional excludes
      statement_deny = (statement_deny + additional_excludes.map { |l| l.to_i }).uniq.sort
    end
    raise "no statement for operation #{operation}" unless statement_allow && statement_deny
    if statement_allow.empty?
      "FALSE" # match nothing (deny list is irrelevant if the allow list is empty)
    elsif statement_deny.empty?
      "(#{column} && '{#{statement_allow.join(',')}}'::int[])"
    else
      "((#{column} && '{#{statement_allow.join(',')}}'::int[]) AND NOT (#{column} && '{#{statement_deny.join(',')}}'::int[]))"
    end
  end

  # For testing/display
  def _internal_states
    [@allow, @deny]
  end

end

# -------------------------------------------------------------------------------------

class KLabelStatementsCombined < KLabelStatements

  def initialize(a, b)
    @a = a
    @b = b
  end

  def ui_display
    [@a, _sql_operator, @b]
  end

  def self._define_combiner_method(symbol)
    define_method(symbol) do |*args|
      _combine(@a.__send__(symbol, *args), @b.__send__(symbol, *args))
    end
  end

  _define_combiner_method :label_is_allowed?
  _define_combiner_method :label_is_denied?
  _define_combiner_method :something_allowed?
  _define_combiner_method :allow?

  def _sql_condition(*args)
    # TODO: Optimise generation of combined SQL conditions - could do much better than this (and intarray has a 'query' operator which uses the index)
    %Q!(#{@a._sql_condition(*args)} #{_sql_operator} #{@b._sql_condition(*args)})!
  end

  # Sub-class implementes these to specify the operators
  def _sql_operator
    raise "Not implemented"
  end
  def _combine(x, y)
    raise "Not implemented"
  end
end

class KLabelStatementsAnd < KLabelStatementsCombined
  def _sql_operator
    "AND"
  end
  def _combine(x, y)
    x && y
  end
end

class KLabelStatementsOr < KLabelStatementsCombined
  def _sql_operator
    "OR"
  end
  def _combine(x, y)
    x || y
  end
end

# -------------------------------------------------------------------------------------

# An alternate implementation for super-users which says yes to everything
class KLabelStatementsSuperUser < KLabelStatements

  def initialize
    super()
  end

  def is_superuser?
    true
  end

  def label_is_allowed?(operation, label)
    true
  end
  def label_is_denied?(operation, label)
    false
  end

  def something_allowed?(operation)
    true
  end

  def allow?(operation, label_list)
    true # super-user can always do everything
  end

  def _sql_condition(operation, column, additional_excludes = nil)
    if additional_excludes != nil
      # Super-user can see everything, except the stuff passed in here
      "(NOT (#{column} && '{#{additional_excludes.map { |l| l.to_i } .uniq.sort.join(',')}}'::int[]))"
    else
      "TRUE" # super-user can see everything
    end
  end

end
