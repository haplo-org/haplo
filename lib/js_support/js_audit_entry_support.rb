# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Provide utility functions to KAuditEntry JavaScript objects

module JSAuditEntrySupport

  AUDIT_ENTRY_KEYS = [
    ["auditEntryType", :kind,     String,   :required,
        proc { |v| (v =~ /\A[a-z0-9_]+\:[a-z0-9_]+\z/) ? nil : "Property auditEntryType must match /^[a-z0-9_]+:[a-z0-9_]+$/" }
    ],
    ["objId",       :objref,      Integer,  :optional],
    ["entityId",    :entity_id,   Integer,  :optional],
    ["displayable", :displayable, nil,      :required,
        proc { |v| (v.kind_of?(TrueClass) || v.kind_of?(FalseClass)) ? nil : "Property displayable must be true or false" }
    ],
    ["data",        :data,        Hash,     :optional]
  ]

  SIMPLE_COLUMN_ATTRIBUTE_MAPPINGS = [
    [:getEntityId, :entity_id],
    [:getDisplayable, :displayable],
    [:getUserId, :user_id],
    [:getAuthenticatedUserId, :auth_user_id],
  ]

  FIELD_TO_COLUMNS = {
    "creationDate" => :created_at,
    "remoteAddress" => :remote_addr,
    "userId" => :user_id,
    "authenticatedUserId" => :auth_user_id,
    "auditEntryType" => :kind,
    "ref" => :objref,
    "entityId" => :entity_id,
    "displayable" => :displayable,
    "data" => :data,
  }

  # Implements O.audit.write()
  def self.write(json)
    # Decode untrusted attributes, then build sanitised version
    untrusted_attributes = JSON.parse(json)
    attributes = Hash.new
    AUDIT_ENTRY_KEYS.each do |name, ruby_name, type, optional, validation|
      if untrusted_attributes.has_key?(name)
        value = untrusted_attributes[name]
        unless type == nil || value.kind_of?(type)
          raise JavaScriptAPIError, "Property #{name} must be a #{type.name.downcase}"
        end
        if validation && nil != (error = validation.call(value))
          raise JavaScriptAPIError, error
        end
        value = KObjRef.new(value) if ruby_name == :objref
        # Attribute looks OK
        attributes[ruby_name] = value
      else
        unless optional == :optional
          raise JavaScriptAPIError, "Property #{name} is required for O.audit.write()"
        end
      end
    end
    # All looks good, create and return an audit entry
    AuditEntry.write(attributes)
  end

  def self.safeGetColumnFromField(field)
    columnName = FIELD_TO_COLUMNS[field]
    # Java KAuditEntry relies on this exception to warn callers of invalid fields at the point of use
    raise JavaScriptAPIError, "Audit entries have no field named '#{field}'." unless columnName != nil
    columnName
  end

  def self.constructQuery(query)
    entries = AuditEntry.where().unsafe_where_sql(
      KObjectStore.user_permissions.sql_for_read_query_filter("labels")
    )

    types = query.getAuditEntryTypes()
    unless types.nil? or types.length == 0
      entries.where_kind_is_one_of(query.getAuditEntryTypes())
    end
    fromDate = query.getFromDate()
    unless fromDate.nil?
      fromTime = Time.at(fromDate.getTime/1000)
      entries.where_created_at_or_after(fromTime)
    end
    toDate = query.getToDate()
    unless toDate.nil?
      toTime = Time.at(toDate.getTime/1000)
      entries.where_created_at_or_before(toTime)
    end
    objId = query.getObjId()
    unless objId.nil?
      entries.where(:objref => KObjRef.new(objId))
    end
    SIMPLE_COLUMN_ATTRIBUTE_MAPPINGS.each do |method, column|
      queryValue = query.send(method);
      unless queryValue.nil?
        entries.where(column => queryValue)
      end
    end
    if query.getSortField.nil?
      entries.order(:recent_first)
    else
      sortOrder = query.getSortDesc() ? "DESC" : "ASC"
      sortColumn = safeGetColumnFromField(query.getSortField)
      entries = entries.unsafe_order("#{sortColumn} #{sortOrder}, created_at DESC")
    end
    unless query.getLimit.nil?
      entries = entries.limit(query.getLimit)
    end
  end

  def self.executeQuery(query, firstResultOnly)
    entries = constructQuery(query)
    firstResultOnly ? [entries.first()].compact : entries.select()
  end

end

Java::OrgHaploJsinterface::KAuditEntry.setRubyInterface(JSAuditEntrySupport)
