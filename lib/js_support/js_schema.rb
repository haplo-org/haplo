# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



module KSchemaToJavaScript

  # This method is called by the update_js_runtime_constants.rb script, then the result committed to source control.
  def self.basic_constants_to_js
    types = Hash.new
    KConstants.constants.each do |constant|
      next unless constant =~ /\AT_[A-Z0-9_]+\z/
      next if constant =~ /\AT_PSEUDO_/
      types[constant] = KConstants.const_get(constant)
    end
    js = "_.extend(O,{\n".dup
    types.keys.sort.each do |constant|
      js << "  #{constant}:#{types[constant]},\n"
    end
    js << "  T_REF:#{KConstants::T_OBJREF}\n" # alias for T_OBJREF to fit in with JS naming
    js << "});\n"
    js
  end

  def self.schema_to_js(schema)
    js = <<-__E .dup
    $schema__runtimeinit__ = function(global) {
      global.TYPE = new $CheckingLookupObject("TYPE");
      global.ATTR = new $CheckingLookupObject("ATTR");
      global.ATTR.Parent=#{KConstants::A_PARENT};
      global.ATTR.Type=#{KConstants::A_TYPE};
      global.ATTR.Title=#{KConstants::A_TITLE};
      global.ALIASED_ATTR = new $CheckingLookupObject("ALIASED_ATTR");
      global.QUAL = new $CheckingLookupObject("QUAL");
      global.LABEL = new $CheckingLookupObject("LABEL");
      global.GROUP = new $CheckingLookupObject("GROUP");
    __E
    objrefs = [] # var name, code (untrusted), objref (trusted)
    values = [] # var name, code (untrusted), value (trusted)
    # Types
    schema.each_type_desc do |type_desc|
      objrefs << ['TYPE', type_desc.code, type_desc.objref]
    end
    # Attributes
    schema.each_attr_descriptor do |attr_desc|
      values << ['ATTR', attr_desc.code, attr_desc.desc]
    end
    # Aliased attributes
    schema.each_aliased_attr_descriptor do |aliased_attr_desc|
      values << ['ALIASED_ATTR', aliased_attr_desc.code, aliased_attr_desc.desc]
    end
    # Qualifiers
    values << ['QUAL', 'std:qualifier:null', KConstants::Q_NULL] # not a 'real' qualifier
    schema.each_qual_descriptor do |qual_desc|
      values << ['QUAL', qual_desc.code, qual_desc.desc]
    end
    # Labels
    objrefs << ['TYPE', 'std:type:label', KConstants::O_TYPE_LABEL] # useful to have label type available to create new labels
    KObjectStore.query_and.link(KConstants::O_TYPE_LABEL, KConstants::A_TYPE).execute(:all, :any).each do |l|
      code = l.first_attr(KConstants::A_CODE)
      if code
        objrefs << ['LABEL', code.to_s, l.objref]
      end
    end
    # Groups
    User.where(:kind => User::KIND_GROUP).order(:id).each do |group|
      values << ['GROUP', group.code, group.id]
    end

    # Write JavaScript to define schema
    objrefs.each do |var, code, objref|
      if code
        js << "global.#{var}[#{code.to_json}]=(new $Ref(#{objref.obj_id}));\n"
      end
    end
    values.each do |var, code, value|
      if code
        js << "global.#{var}[#{code.to_json}]=#{value};\n"
      end
    end
    # SCHEMA object
    js << <<-__E
      global.SCHEMA = new $CheckingLookupObject("SCHEMA");
      O.$private.prepareSCHEMA(SCHEMA);
      _.extend(SCHEMA, {
        TYPE: global.TYPE,
        ATTR: global.ATTR,
        ALIASED_ATTR: global.ALIASED_ATTR,
        QUAL: global.QUAL,
        LABEL: global.LABEL,
        GROUP: global.GROUP
      });
    __E
    # Plugin specific schema information from requirements files
    js << "O.$private.preparePluginSchemaRequirements(#{KApp.global(:js_plugin_schema_requirements) || '{}'});\n};"
    js
  end

  # Sync with schema_requirements_app.rb
  TYPE_BEHAVIOURS = {
    KConstants::O_TYPE_BEHAVIOUR_CLASSIFICATION => "classification",
    KConstants::O_TYPE_BEHAVIOUR_PHYSICAL => "physical",
    KConstants::O_TYPE_BEHAVIOUR_HIERARCHICAL => "hierarchical",
    KConstants::O_TYPE_BEHAVIOUR_SHOW_HIERARCHY => "show-hierarchy",
    KConstants::O_TYPE_BEHAVIOUR_FORCE_LABEL_CHOICE => "force-label-choice",
    KConstants::O_TYPE_BEHAVIOUR_SELF_LABELLING => "self-labelling",
    KConstants::O_TYPE_BEHAVIOUR_HIDE_FROM_BROWSE => "hide-from-browse"
  }

  # Schema query functions
  def self.get_schema_type_info(schema, obj_id)
    type_desc = schema.type_descriptor(KObjRef.new(obj_id))
    return nil if type_desc.nil?
    attrs = []
    aliased_attrs = []
    type_desc.attributes.each do |desc|
      aliased = schema.aliased_attribute_descriptor(desc)
      aliased_attrs << aliased.desc unless aliased == nil
      attrs << ((aliased == nil) ? desc : aliased.alias_of)
    end
    elements = []
    KSchemaApp.each_display_element(type_desc.display_elements) { |g,p,element_name,o| elements << element_name }
    info = {
      :name => type_desc.printable_name.to_s,
      :shortName => type_desc.short_names.first.to_s,
      :rootType => (type_desc.root_type || type_desc.objref).obj_id,
      :childTypes => type_desc.children_types.map { |r| r.obj_id },
      :behaviours => type_desc.behaviours.map { |r| TYPE_BEHAVIOURS[r] } .compact,
      :annotations => type_desc.annotations,
      :createShowType => type_desc.create_show_type,
      :elements => elements.sort(),
      :attributes => attrs,
      :aliasedAttributes => aliased_attrs
    }
    info[:parentType] = type_desc.parent_type.obj_id if type_desc.parent_type
    info[:code] = type_desc.code if type_desc.code
    info.to_json
  end

  def self.get_schema_attribute_info(schema, obj_id)
    attr_desc = schema.attribute_descriptor(obj_id)
    return nil if attr_desc.nil?
    info = {
      :name => attr_desc.printable_name.to_s,
      :shortName => attr_desc.short_name.to_s,
      :typecode => attr_desc.data_type || KConstants::T_TEXT,
      :types => attr_desc.control_by_types.map { |t| t.obj_id },
      :allowedQualifiers => attr_desc.allowed_qualifiers.sort
    }
    info[:code] = attr_desc.code if attr_desc.code
    info[:groupType] = attr_desc.attribute_group_type.obj_id if attr_desc.attribute_group_type
    info.to_json
  end

  def self.get_schema_aliased_attribute_info(schema, obj_id)
    aliased_desc = schema.aliased_attribute_descriptor(obj_id)
    return nil if aliased_desc.nil?
    info = {
      :name => aliased_desc.printable_name.to_s,
      :shortName => aliased_desc.short_name.to_s,
      :aliasOf => aliased_desc.alias_of
    }
    info[:code] = aliased_desc.code if aliased_desc.code
    info.to_json
  end

  def self.get_schema_qualifier_info(schema, obj_id)
    qual_desc = schema.qualifier_descriptor(obj_id)
    return nil if qual_desc.nil?
    info = {
      :name => qual_desc.printable_name.to_s,
      :shortName => qual_desc.short_name.to_s
    }
    info[:code] = qual_desc.code if qual_desc.code
    info.to_json
  end
end

