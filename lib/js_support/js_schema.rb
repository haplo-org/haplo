# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
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
    js = "_.extend(O,{\n"
    types.keys.sort.each do |constant|
      js << "  #{constant}:#{types[constant]},\n"
    end
    js << "  T_REF:#{KConstants::T_OBJREF}\n" # alias for T_OBJREF to fit in with JS naming
    js << "});\n"
    js
  end

  def self.schema_to_js(schema)
    js = <<-__E
      var TYPE = new $CheckingLookupObject("TYPE");
      var ATTR = new $CheckingLookupObject("ATTR");
      ATTR.Parent=#{KConstants::A_PARENT};
      ATTR.Type=#{KConstants::A_TYPE};
      ATTR.Title=#{KConstants::A_TITLE};
      var ALIASED_ATTR = new $CheckingLookupObject("ALIASED_ATTR");
      var QUAL = new $CheckingLookupObject("QUAL");
      var LABEL = new $CheckingLookupObject("LABEL");
      var GROUP = new $CheckingLookupObject("GROUP");
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
    User.find_all_by_kind(User::KIND_GROUP).each do |group|
      values << ['GROUP', group.code, group.id]
    end

    # Write JavaScript to define schema
    objrefs.each do |var, code, objref|
      if code
        js << "#{var}[#{code.to_json}]=(new $Ref(#{objref.obj_id}));\n"
      end
    end
    values.each do |var, code, value|
      if code
        js << "#{var}[#{code.to_json}]=#{value};\n"
      end
    end
    # SCHEMA object
    js << <<-__E
      var SCHEMA = new $CheckingLookupObject("SCHEMA");
      _.extend(SCHEMA, {
        getTypeInfo: function(type) {
          return O.$private.$bootstrapSchemaQuery("getTypeInfo", type);
        },
        getAttributeInfo: function(attr) {
          return O.$private.$bootstrapSchemaQuery("getAttributeInfo", attr);
        },
        getQualifierInfo: function(attr) {
          return O.$private.$bootstrapSchemaQuery("getQualifierInfo", attr);
        },
        $console: function() {
          return '[SCHEMA]';
        },
        TYPE: TYPE,
        ATTR: ATTR,
        ALIASED_ATTR: ALIASED_ATTR,
        QUAL: QUAL,
        LABEL: LABEL,
        GROUP: GROUP
      });
    __E
    js
  end

  # Generate the lazily created schema query functions
  def self.generate_schema_query_function(schema, queryName)
    js = "(function() {\n"
    case queryName
    when "getTypeInfo"
      js << "  var _info = new $RefKeyDictionary();\n"
      schema.each_type_desc do |type_desc|
        attrs = []
        type_desc.attributes.each do |desc|
          aliased = schema.aliased_attribute_descriptor(desc)
          attrs << ((aliased == nil) ? desc : aliased.alias_of)
        end
        info = {
          :name => type_desc.printable_name.to_s,
          :shortName => type_desc.short_names.first.to_s,
          :rootType => type_desc.root_type.obj_id,
          :attributes => attrs
        }
        info[:parentType] = type_desc.parent_type.obj_id if type_desc.parent_type
        info[:code] = type_desc.code if type_desc.code
        js << "  _info.set(new $Ref(#{type_desc.objref.obj_id}), #{info.to_json});\n"
      end
      js << <<-__E
      O.$private.$bootstrapSchemaQueryTypesConvert(_info);
      SCHEMA.getTypeInfo = function(type) {
        return _info.get(type);
      };
      __E

    when "getAttributeInfo"
      attrs = {}
      schema.each_attr_descriptor do |attr_desc|
        info = {
          :name => attr_desc.printable_name.to_s,
          :shortName => attr_desc.short_name.to_s,
          :typecode => attr_desc.data_type || T_TEXT,
          :types => attr_desc.control_by_types.map { |t| t.obj_id }
        }
        info[:code] = attr_desc.code if attr_desc.code
        attrs[attr_desc.desc] = info
      end
      js << <<-__E
        var _info = #{attrs.to_json};
        O.$private.$bootstrapSchemaQueryAttributesConvert(_info);
        SCHEMA.getAttributeInfo = function(attr) {
          return _info[attr];
        };
      __E

    when "getQualifierInfo"
      quals = {}
      schema.each_qual_descriptor do |qual_desc|
        info = {
          :name => qual_desc.printable_name.to_s,
          :shortName => qual_desc.short_name.to_s
        }
        info[:code] = qual_desc.code if qual_desc.code
        quals[qual_desc.desc] = info
      end
      js << <<-__E
        var _info = #{quals.to_json};
        SCHEMA.getQualifierInfo = function(qual) {
          return _info[qual];
        };
      __E

    else
      raise "Unknown queryName for KSchemaToJavaScript.generate_schema_query_function: '#{queryName}'"
    end
    js << "})();"
    js
  end
end

