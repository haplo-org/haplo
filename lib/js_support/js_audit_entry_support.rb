# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Provide utility functions to KAuditEntry JavaScript objects

module JSAuditEntrySupport

  AUDIT_ENTRY_KEYS = [
    ["auditEntryType", :kind,     String,   :required,
        proc { |v| (v =~ /\A[a-z0-9_]+\:[a-z0-9_]+\z/) ? nil : "Property auditEntryType must match /^[a-z0-9_]+:[a-z0-9_]+$/" }
    ],
    ["objId",       :obj_id,      Integer,  :optional],
    ["entityId",    :entity_id,   Integer,  :optional],
    ["displayable", :displayable, nil,      :required,
        proc { |v| (v.kind_of?(TrueClass) || v.kind_of?(FalseClass)) ? nil : "Property displayable must be true or false" }
    ],
    ["data",        :data,        Hash,     :optional]
  ]

  SIMPLE_COLUMN_ATTRIBUTE_MAPPINGS = [
    [:getObjId, :obj_id],
    [:getEntityId, :entity_id],
    [:getDisplayable, :displayable],
    [:getUserId, :user_id],
    [:getAuthenticatedUserId, :auth_user_id],
  ]

  DB_COLUMN_TYPE_MAPPINGS = {
    :displayable => proc { |v| { 't' => true, 'f' => false }[v] },
    :data => proc { |v| JSON.parse v },
    :user_id => proc  { |v| Integer v },
    :auth_user_id =>  proc { |v| Integer v },
    :entity_id =>  proc { |v| Integer v },
    :obj_id => proc { |v| KObjRef.new(v.to_i).to_presentation }
  }

  FIELD_TO_COLUMNS = {
    "creationDate" => :created_at,
    "remoteAddress" => :remote_addr,
    "userId" => :user_id,
    "authenticatedUserId" => :auth_user_id,
    "auditEntryType" => :kind,
    "ref" => :obj_id,
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
    entries = AuditEntry.where(nil)
    permissions = KObjectStore.active_permissions
    unless permissions.nil?
      entries = entries.where(permissions._sql_condition(:read, "labels"))
    end

    types = query.getAuditEntryTypes()
    unless types.nil? or types.length == 0
      entries = entries.where("kind IN (?)", query.getAuditEntryTypes())
    end
    fromDate = query.getFromDate()
    unless fromDate.nil?
      fromTime = Time.at(fromDate.getTime/1000)
      entries = entries.where("created_at >= ?", fromTime)
    end
    toDate = query.getToDate()
    unless toDate.nil?
      toTime = Time.at(toDate.getTime/1000)
      entries = entries.where("created_at <= ?", toTime)
    end
    SIMPLE_COLUMN_ATTRIBUTE_MAPPINGS.each do |method, column|
      queryValue = query.send(method);
      unless queryValue.nil?
        entries = entries.where("#{column} = ?", queryValue)
      end
    end
    unless query.getSortField.nil?
      sortOrder = query.getSortDesc() ? "DESC" : "ASC"
      sortColumn = safeGetColumnFromField(query.getSortField)
      entries = entries.order("#{sortColumn} #{sortOrder}")
    end
    unless query.getLimit.nil?
      entries = entries.limit(query.getLimit)
    end
    entries.order("created_at DESC")
  end

  def self.executeQuery(query, firstResultOnly)
    entries = constructQuery(query)
    firstResultOnly ? [entries.first].compact : entries.to_a
  end

  def self.executeTable(query, fieldNames)
    columnNames = fieldNames.to_a.map { |f| safeGetColumnFromField f }
    entries = constructQuery(query).select(columnNames.join(", "))
    results = KApp.get_pg_database.perform(entries.to_sql).to_a
    results.map! do |row|
      columnNames.zip(row).map do |name, value|
        if value.nil?
          value
        else
          converter = DB_COLUMN_TYPE_MAPPINGS[name]
          converter ? converter.call(value) : value
        end
      end
    end
    data = results.to_json.to_java_bytes
    Java::ComOneisJsinterfaceGenerate::KGeneratedBinaryData.new(nil, "application/json", data)
  end

end

Java::ComOneisJsinterface::KAuditEntry.setRubyInterface(JSAuditEntrySupport)
