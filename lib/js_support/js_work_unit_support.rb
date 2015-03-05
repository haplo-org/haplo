# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
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
    # Build query
    units = WorkUnit.where(:work_type => query.getWorkType())

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

    obj_id = query.getObjId()
    units = units.where(:obj_id => obj_id) if obj_id != nil

    # Execute query
    units = units.order("created_at DESC,id DESC")
    if firstResultOnly
      first = units.first
      (first == nil) ? [] : [first]
    else
      units.to_a
    end
  end

end

Java::ComOneisJsinterface::KWorkUnit.setRubyInterface(JSWorkUnitSupport)
