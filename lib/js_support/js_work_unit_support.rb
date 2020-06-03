# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



# Provide utility functions to KWorkUnit JavaScript objects

module JSWorkUnitSupport

  def self.constructWorkUnit(workType)
    wu = WorkUnit.new
    wu.work_type = workType
    wu
  end

  def self.loadWorkUnit(id)
    WorkUnit.read(id)
  end

  def self.executeQuery(query, firstResultOnly)
    units = build_ruby_query(query).order(:stable_created_at)
    if firstResultOnly
      first = units.first()
      (first == nil) ? [] : [first]
    else
      units.select()
    end
  end

  def self.executeCount(query)
    build_ruby_query(query).count()
  end

  def self.executeCountByTagsJSON(query, tags)
    tags = tags.to_a.compact
    if tags.empty?
      raise JavaScriptAPIError, "countByTags() requires at least one tag."
    end
    # Work out indices of values in result set (columns start at 1)
    path = 1...(tags.length)
    last_tag_index = tags.length
    count_index = tags.length + 1
    # Build query
    quoted_tags = tags.map { |tag| PGconn.quote(tag) }
    tag_values = quoted_tags.map { |qtag| "tags -> #{qtag}" } .join(', ')
    select = quoted_tags.each_with_index.map { |qtag, i| "tags -> #{qtag} as count_tag#{i}" } .join(', ')
    select << ", COUNT(*) as count_total"
    rq = build_ruby_query(query)
    where_sql = rq.unsafe_get_where_clause_sql()
    where_sql = "WHERE #{where_sql}" unless where_sql.empty?
    sql = "SELECT #{select} FROM #{KApp.db_schema_name}.work_units #{where_sql} GROUP BY #{tag_values} ORDER BY #{tag_values}"
    # Execute query
    result = {}
    KApp.with_jdbc_database do |db|
      statement = db.prepareStatement(sql)
      rq.unsafe_insert_values_for_where_clause(statement)
      qresults = statement.executeQuery()
      while qresults.next()
        counts = result
        path.each do |i|
          tag = qresults.getString(i) || ''
          counts = (counts[tag] ||= {})
        end
        last_tag = qresults.getString(last_tag_index) || ''
        # Because NULL and "" are counted the same, add the total to any existing value, even though
        # the database will have done all the summing in the query for all the other values.
        counts[last_tag] = (counts[last_tag] || 0) + qresults.getLong(count_index)
      end
    end
    return JSON.generate(result)
  end

  def self.build_ruby_query(query)
    # Build query, which must select on at least one criteria
    work_type = query.getWorkType()
    obj_id = query.getObjId()
    tagValues = query.getTagValues()
    deadline_missed = query.getDeadlineMissed()
    unless work_type || obj_id || deadline_missed || (tagValues && (tagValues.length > 0))
      raise JavaScriptAPIError, "Work unit queries must specify at least a work type, a ref, deadlineMissed, or a tag"
    end
    units = WorkUnit.where()
    units.where(:work_type => work_type) if work_type
    units.where(:objref => KObjRef.new(obj_id)) if obj_id

    status = query.getStatus();
    if status == "open"
      units.where_is_open()
    elsif status == "closed"
      units.where_is_closed()
    elsif status != nil
      raise "logic error, bad status #{status}"  # should never run
    end

    visibility = query.getVisibility();
    if visibility == "visible"
      units.where(:visible => true)
    elsif visibility == "not-visible"
      units.where(:visible => false)
    elsif visibility != nil
      raise "logic error, bad visibility #{visibility}"  # should never run
    end

    created_by_id = query.getCreatedById()
    units.where(:created_by_id => created_by_id) if created_by_id != nil

    actionable_by_id = query.getActionableById()
    if actionable_by_id != nil
      user = User.cache[actionable_by_id]
      units.where_is_actionable_by_user([user.id] + user.groups_ids)
    end

    if deadline_missed
      units.where_deadline_missed()
    end

    closed_by_id = query.getClosedById()
    units.where(:closed_by_id => closed_by_id) if closed_by_id != nil

    # TODO: Remove _temp_refPermitsReadByUserId and/or replace by proper interface
    _temp_refPermitsReadByUserId = query.get_temp_refPermitsReadByUserId()
    if _temp_refPermitsReadByUserId
      ruser = User.cache[_temp_refPermitsReadByUserId]
      raise JavaScriptAPIError, "user doesn't exist" unless ruser
      # This breaks the separation between database and object store, which should really have been maintained
      # Also the SQL will repeat the SELECT statement many times, so let's hope the pg optimiser is good.
      units.unsafe_where_sql("(obj_id IS NOT NULL AND #{ruser.permissions._sql_condition(:read, "(SELECT labels FROM #{KApp.db_schema_name}.os_objects WHERE os_objects.id=obj_id)")})")
    end

    if tagValues != nil
      tagValues.each do |kv|
        if kv.value.nil?
          units.where_tag_is_empty_string_or_null(kv.key)
        else
          units.where_tag(kv.key, kv.value)
        end
      end
    end

    units
  end

end

Java::OrgHaploJsinterface::KWorkUnit.setRubyInterface(JSWorkUnitSupport)
