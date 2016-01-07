# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Provide utility functions to KQueryClause JavaScript objects

module JSKQueryClauseSupport
  java_import java.util.GregorianCalendar
  java_import java.util.Calendar

  def self.constructQuery()
    KObjectStore.query_and
  end

  def self.queryFromQueryString(query)
    q = KObjectStore.query_and
    KQuery.new(query).add_query_to(q, [])
    q
  end

  ALLOWED_EXECUTE_QUERY_SORT_BY = {
    "date" => :date, "date_asc" => :date_asc, "relevance" => :relevance,
    "any" => :any, "title" => :title, "title_desc" => :title_desc
  }
  def self.executeQuery(query, sparseResults, sort, deletedOnly, includeArchived)
    # Only allow access to things in the store
    query.add_exclude_labels([KConstants::O_LABEL_STRUCTURE])
    # Set inclusion of deleted objects
    query.include_deleted_objects(deletedOnly ? :deleted_only : :exclude_deleted)
    # Set inclusion of archived objects
    query.include_archived_objects(includeArchived ? :include_archived : :exclude_archived)
    # Check sort option is valid
    sort_symbol = ALLOWED_EXECUTE_QUERY_SORT_BY[sort]
    raise JavaScriptAPIError, "Bad sort option for JSSupportRoot#executeQuery" if sort_symbol == nil
    query.execute(sparseResults ? :reference : :all, sort_symbol)
    # TODO: Checks on whether sparseResults is being used correctly by JavaScript code
  end

  def self.convertDate(value)
    return nil if value == nil
    if value.kind_of?(java.util.Date)
      c = GregorianCalendar.new
      c.setTime(value)
      DateTime.civil(c.get(Calendar::YEAR), c.get(Calendar::MONTH) + 1, c.get(Calendar::DAY_OF_MONTH),
          c.get(Calendar::HOUR_OF_DAY), c.get(Calendar::MINUTE), c.get(Calendar::SECOND))
    else
      nil
    end
  end

end

Java::ComOneisJsinterface::KQueryClause.setRubyInterface(JSKQueryClauseSupport)
