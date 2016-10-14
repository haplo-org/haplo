# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Provide utility functions to KWorkUnit JavaScript objects

module JSWorkUnitSupport

  def self.constructWorkUnit(workType)
    WorkUnit.new(:work_type => workType)
  end

  def self.loadWorkUnit(id)
    WorkUnit.find(id)
  end

  def self.executeQuery(query, firstResultOnly)
    units = build_ruby_query(query).order("created_at DESC,id DESC")
    if firstResultOnly
      first = units.first
      (first == nil) ? [] : [first]
    else
      units.to_a
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
    path_methods = COUNT_VALUE_METHODS[0..(tags.length-1)]
    last_method = path_methods.pop
    quoted_tags = tags.map { |tag| PGconn.quote(tag) }
    tag_values = quoted_tags.map { |qtag| "tags -> #{qtag}" } .join(', ')
    select = quoted_tags.each_with_index.map { |qtag, i| "tags -> #{qtag} as count_tag#{i}" } .join(', ')
    select << ", COUNT(*) as count_total"
    result = {}
    build_ruby_query(query).group(tag_values).order(tag_values).select(select).each do |wu|
      counts = result
      path_methods.each do |method|
        tag = wu.__send__(method) || ''
        counts = (counts[tag] ||= {})
      end
      last_tag = wu.__send__(last_method) || ''
      # Because NULL and "" are counted the same, add the total to any existing value, even though
      # the database will have done all the summing in the query for all the other values.
      counts[last_tag] = (counts[last_tag] || 0) + wu.count_total
    end
    return JSON.generate(result)
  end
  COUNT_VALUE_METHODS = [:count_tag0, :count_tag1, :count_tag2, :count_tag3]

  def self.build_ruby_query(query)
    # Build query, which must select on at least one criteria
    work_type = query.getWorkType()
    obj_id = query.getObjId()
    tagValues = query.getTagValues()
    unless work_type || obj_id || (tagValues && (tagValues.length > 0))
      raise JavaScriptAPIError, "Work unit queries must specify at least a work type, a ref, or a tag"
    end
    units = WorkUnit
    units = units.where(:work_type => work_type) if work_type
    units = units.where(:obj_id => obj_id) if obj_id

    status = query.getStatus();
    if status == "open"
      units = units.where('closed_at IS NULL')
    elsif status == "closed"
      units = units.where('closed_at IS NOT NULL')
    elsif status != nil
      raise "logic error, bad status #{status}"  # should never run
    end

    visibility = query.getVisibility();
    if visibility == "visible"
      units = units.where('visible=TRUE')
    elsif visibility == "not-visible"
      units = units.where('visible=FALSE')
    elsif visibility != nil
      raise "logic error, bad visibility #{visibility}"  # should never run
    end

    created_by_id = query.getCreatedById()
    units = units.where(:created_by_id => created_by_id) if created_by_id != nil

    actionable_by_id = query.getActionableById()
    if actionable_by_id != nil
      user = User.cache[actionable_by_id]
      units = units.where("actionable_by_id IN (#{([user.id] + user.groups_ids).join(',')})")
    end

    closed_by_id = query.getClosedById()
    units = units.where(:closed_by_id => closed_by_id) if closed_by_id != nil

    # TODO: Remove _temp_refPermitsReadByUserId and/or replace by proper interface
    _temp_refPermitsReadByUserId = query.get_temp_refPermitsReadByUserId()
    if _temp_refPermitsReadByUserId
      ruser = User.cache[_temp_refPermitsReadByUserId]
      raise JavaScriptAPIError, "user doesn't exist" unless ruser
      # This breaks the separation between database and object store, which should really have been maintained
      # Also the SQL will repeat the SELECT statement many times, so let's hope the pg optimiser is good.
      units = units.where("(obj_id IS NOT NULL AND #{ruser.permissions._sql_condition(:read, '(SELECT labels FROM os_objects WHERE os_objects.id=obj_id)')})")
    end

    if tagValues != nil
      tagValues.each do |kv|
        if kv.value.nil?
          units = units.where(WorkUnit::WHERE_TAG_IS_EMPTY_STRING_OR_NULL, kv.key)
        else
          units = units.where(WorkUnit::WHERE_TAG, kv.key, kv.value)
        end
      end
    end

    units
  end

end

Java::OrgHaploJsinterface::KWorkUnit.setRubyInterface(JSWorkUnitSupport)
