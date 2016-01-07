# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class Setup_SchemaRequirementsController < ApplicationController
  include KConstants
  policies_required :not_anonymous, :setup_system
  include SystemManagementHelper

  def render_layout
    'management'
  end

  _GetAndPost
  def handle_apply
    if request.post?
      @requirements = params[:requirements] || ''
      applier = SchemaRequirements.applier_for_requirements_file(@requirements)
      KApp.logger.info("Applying one-off requirements from admin user")
      applier.apply.commit
      @errors = applier.errors
      KApp.logger.info("Errors: #{@errors.join("\n")}")
    end
  end

  SCHEMA_OBJECT_TYPES_IN_ORDER = [
      [O_TYPE_LABEL, "Labels"],
      [O_TYPE_QUALIFIER_DESC, "Qualifiers"],
      [O_TYPE_ATTR_DESC, "Attributes"],
      [O_TYPE_ATTR_ALIAS_DESC, "Aliased attributes"],
      [O_TYPE_APP_VISIBLE, "Types"]
    ]
  OMIT_OBJECTS = [KObjRef.new(A_TITLE), KObjRef.new(A_TYPE), KObjRef.new(A_PARENT)]

  _GetAndPost
  def handle_generate
    return unless request.post?
    short_standard_names = !!(params[:short_std])
    # Recusively read all the schema objects relevant to the selected types
    refs_to_read = (params[:types] || {}).keys.map { |t| KObjRef.from_presentation(t) } .compact
    selected_types = refs_to_read.dup
    is_short_defn = Proc.new do |objref|
      (short_standard_names && (objref.obj_id < MAX_RESERVED_OBJID) && !(selected_types.include?(objref)))
    end
    refs_done = {}
    schema_objects_by_type = Hash.new { |h,k| h[k] = [] }
    safety = 16
    while (safety > 0) && (refs_to_read.length > 0)
      next_refs_to_read = []
      refs_to_read.each do |ref|
        refs_done[ref] = true
        object = begin
          KObjectStore.read(ref)
        rescue => e
          # ignore exceptions reading objects
        end
        unless object
          KApp.logger.warn("Failed to read object #{ref.to_presentation} when generating schema")
        else
          obj_type = object.first_attr(A_TYPE)
          if obj_type
            schema_objects_by_type[obj_type] << object
            # Find all the schema objects this object refers to, unless it's a short definition
            unless is_short_defn.call(object.objref)
              object.each do |v,d,q|
                if v.kind_of?(KObjRef) && !(refs_done.has_key?(v))
                  refs_done[v] = true
                  next_refs_to_read << v
                end
              end
            end
          end
        end
      end
      safety -= 1
      refs_to_read = next_refs_to_read
    end
    # Output schema definitions
    @generated_requirements_short = ""
    @generated_requirements = ""
    requirements_app_context = SchemaRequirements::AppContext.new
    SCHEMA_OBJECT_TYPES_IN_ORDER.each do |type_ref, comment|
      objects = schema_objects_by_type[type_ref].sort do |a,b|
        a.first_attr(A_TITLE).to_s <=> b.first_attr(A_TITLE).to_s
      end
      unless objects.empty?
        @generated_requirements_short << "\n" unless @generated_requirements_short.empty? || @generated_requirements_short.end_with?("\n\n")
        @generated_requirements << "\n" unless @generated_requirements.empty? || @generated_requirements.end_with?("\n\n")
        first_long = true
        objects.each do |object|
          unless OMIT_OBJECTS.include?(object.objref)
            short_defn = is_short_defn.call(object.objref)
            if first_long
              unless short_defn
                @generated_requirements << "\n# -------- #{comment} #{'-'*(40-comment.length)}\n\n"
                first_long = false
              end
            end
            req_text = requirements_app_context.generate_requirements_definition(object, short_defn)
            if req_text
              (short_defn ? @generated_requirements_short : @generated_requirements) << req_text
            end
          end
        end
      end
    end
    @generated_requirements_short << "\n" unless @generated_requirements_short.empty?

    # Groups?
    if params[:groups]
      @generated_requirements << "\n# -------- Groups ----------------------------------\n\n"
      groups = User.find(:all, :conditions => "kind=#{User::KIND_GROUP} AND code IS NOT NULL", :order => 'name')
      gid_to_code = {}
      groups.each do |group|
        gid_to_code[group.id] = group.code
      end
      groups.each do |group|
        @generated_requirements << "group #{group.code} as #{group.name.gsub(/\b(.)/) { $1.upcase }.gsub(' ','')}\n"
        @generated_requirements << "    title: #{group.name}\n"
        group.direct_member_ids.each do |id|
          code = gid_to_code[id]
          @generated_requirements << "    member #{code}\n" if code
        end
        @generated_requirements << "\n"
      end
    end

    # Generic objects?
    if params[:objects]
      @generated_requirements << "\n# -------- Objects ---------------------------------\n\n"
      objects = KObjectStore.query_and.
          any_indentifier_of_type(T_IDENTIFIER_CONFIGURATION_NAME, A_CONFIGURED_BEHAVIOUR).
          execute(:all, :title)
      type_ref_to_code = Hash.new do |h,k|
        td = KObjectStore.schema.type_descriptor(k)
        h[k] = td ? td.code : nil
      end
      objref_to_code = {}
      objects.each do |object|
        objref_to_code[object.objref] = object.first_attr(A_CONFIGURED_BEHAVIOUR).to_s
      end
      objects.each do |object|
        type_code = type_ref_to_code[object.first_attr(A_TYPE)]
        if type_code
          @generated_requirements << "object #{objref_to_code[object.objref]}\n    type #{type_code}\n"
          @generated_requirements << "    title: #{object.first_attr(A_TITLE).to_s.gsub(/\s+/,' ').strip}\n"
          parent_ref = object.first_attr(A_PARENT)
          if parent_ref
            @generated_requirements << "    parent #{objref_to_code[parent_ref]}\n" if objref_to_code[parent_ref]
          end
          notes = object.first_attr(A_NOTES)
          if notes
            @generated_requirements << "    notes: #{notes.to_s.gsub(/\s+/,' ').strip}\n"
          end
          @generated_requirements << "\n"
        end
      end
    end

    if params[:email_templates]
      @generated_requirements << "\n# -------- Email templates -------------------------\n\n"
      requirements_app_context.email_templates.each_key do |code|
        @generated_requirements << requirements_app_context.apply_for_email_template(code).
            generate_requirements_definition('email-template', false, requirements_app_context)
      end
    end

    # Features?
    if params[:features]
      @generated_requirements << "\n# -------- Features --------------------------------\n\n"
      home_page_elements = (KApp.global(:home_page_elements) || '').split(/[\r\n]+/)
      unless home_page_elements.empty?
        @generated_requirements << "feature std:page:home\n"
        home_page_elements.each { |e| @generated_requirements << "    element: #{e}\n" }
        @generated_requirements << "\n"
      end

      configuration_data = JSON.parse(KApp.global(:javascript_config_data) || '{}')
      unless configuration_data.empty?
        @generated_requirements << "feature std:configuration-data\n"
        configuration_data.each do |k,v|
          json = {}; json[k] = v
          @generated_requirements << "    property: #{JSON.generate(json)}\n"
        end
        @generated_requirements << "\n"
      end

      # Only include plugin navigation with group everyone, as this can be used to do everything else
      nav_entries = []
      YAML::load(KApp.global(:navigation)).each do |group, kind, *info|
        if kind == 'plugin' && (group.to_i == User::GROUP_EVERYONE)
          nav_entries << "plugin #{info.first}"
        end
      end
      unless nav_entries.empty?
        @generated_requirements << "feature std:navigation\n"
        nav_entries.each do |line|
          @generated_requirements << "    entry: #{line}\n"
        end
        @generated_requirements << "\n"
      end
    end
  end

end
