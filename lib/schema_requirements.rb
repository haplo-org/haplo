# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module SchemaRequirements

  SORT_REMOVE = -1
  SORT_REMOVE_FORCE = -2
  # Default sort value is chosen so requirements can put things before and after the default sort without using silly sort values
  SORT_DEFAULT = 10000
  # Always include colons for consistency in fields which tend to have spaces
  KEYS_WITH_COLONS = ['title', 'search-name', 'render-icon', 'notes', 'part', 'description', 'purpose']

  # ---------------------------------------------------------------------------------------------------------------

  # Parse a requirements.schema file, collecting schema name mappings on a per-plugin basis

  class Parser
    def initialize()
      @errors = []
      @requirements = Hash.new { |h,k| h[k] = {} }
      @schema_for_plugin = {}
      @number_of_files = 0
    end
    attr_reader :errors, :requirements, :schema_for_plugin, :number_of_files

    IGNORE_LINE = /\A\s*(\#.+)?\z/m # comment or blank line
    OBJECT_FORMAT = /\A(?<optional>OPTIONAL )?(?<kind>\S+)\s+(?<code>[a-zA-Z0-9_:-]+)\s*(as\s+(?<name>[a-zA-Z0-9_]+))?\s*\z/m
    VALUE_FORMAT = /\A\s+((?<remove>(?<forceremove>(FORCE-)?)REMOVE\b)\s*)?(?<key>\S+?):?\s+(?<string>.+?)\s*(\[sort=(?<sort>\d+)\])?\s*\z/m
    OPTIONAL_NAMES_KEY = "_optional".freeze
    TEMPLATE_KIND = "schema-template".freeze
    TEMPLATE_KEY = "apply-schema-template".freeze

    def parse(plugin_name, io)
      @number_of_files += 1
      current_requirement = nil
      line_number = 0
      names = @schema_for_plugin[plugin_name] = Hash.new { |h,k| h[k] = {} }
      io.each do |line|
        line_number += 1
        next if line =~ IGNORE_LINE
        if current_requirement && (match = VALUE_FORMAT.match(line))
          sortstr = match[:sort]
          sort = (sortstr && !sortstr.empty?) ? sortstr.to_i : SORT_DEFAULT
          remove = match[:remove]
          if remove && !remove.empty?
            sort = match[:forceremove].empty? ? SORT_REMOVE : SORT_REMOVE_FORCE
          end
          key = match[:key]
          if key == TEMPLATE_KEY
            current_requirement.add_template(match[:string])
          else
            current_requirement.add_value(sort, key, match[:string])
          end
        elsif (match = OBJECT_FORMAT.match(line))
          kind = match[:kind]
          code = match[:code]
          name = match[:name]
          optional = match[:optional]
          if name && !name.empty?
            local_names = names[kind] # fetch the lookup for the kind, even if optional, to make sure it exists
            if optional
              (names[OPTIONAL_NAMES_KEY][kind] ||= {})[name] = code
            else
              local_names[name] = code
            end
          end
          current_requirement = (@requirements[kind][code] ||= begin
            ((kind == TEMPLATE_KIND) ? TemplateRequirement : Requirement).new(kind, code)
          end)
          # Keep track of whether an object is declared as optional
          current_requirement.declared_as_non_optional = true unless optional
        else
          @errors.push("#{plugin_name} line #{line_number}: #{line.strip}")
        end
      end
      self
    end

    def apply_templates
      template_requirements = @requirements.delete(TEMPLATE_KIND)
      return unless template_requirements
      @requirements.each do |kind,reqs|
        reqs.each do |code,requirement|
          templates = requirement.templates
          if templates
            templates.each do |template_name|
              if template = template_requirements[template_name]
                template.apply_to_requirement(requirement)
              end
            end
          end
        end
      end
    end
  end

  # ---------------------------------------------------------------------------------------------------------------

  # Requirements for values in schema objects, with logic for choosing potential values
  # Multi-values: Don't include any requested values in the list of REMOVED values
  # Single-values: Same as multi-value, but choose the single value with the highest sort order

  class Requirement
    def initialize(kind, code)
      @kind = kind
      @code = code
      @values = Hash.new { |h,k| h[k] = RequiredValue.new }
    end
    attr_accessor :declared_as_non_optional
    attr_reader :kind, :code, :values, :templates
    def add_value(sort, key, value)
      @values[key].set(sort, value)
    end
    def add_template(template_name)
      @templates ||= []
      @templates.push(template_name)
    end
    def _dump
      @values.each do |code,value|
        puts "    #{code}"
        value._dump
      end
    end
  end

  class TemplateRequirement < Requirement
    def initialize(kind, code)
      super(kind, code)
      @template_values = []
    end
    def add_value(*args)
      @template_values << args
    end
    def apply_to_requirement(requirement)
      @template_values.each do |args|
        requirement.add_value(*args)
      end
    end
  end

  class RequiredValue
    def initialize
      @values = []
      @forceremove = []
      @remove = []
    end
    def set(sort, value)
      case sort
      when SORT_REMOVE_FORCE; @forceremove.push(value); @forceremove.uniq!
      when SORT_REMOVE;       @remove.push(value);      @remove.uniq!
      else
        # Don't add an additional value if there's already one for that value, so that
        #  1) multiple plugins can specify the same values for multi-values without duplicating them,
        #  2) the highest priority plugin sets the sort order for a given value.
        unless @values.find { |s,v| v == value }
          @values.push([sort, value])
        end
      end
    end
    def multi_value
      apply = []
      # Use n and sort_by to give a stable sort
      n = 0
      @values.sort_by { |x| n += 1; [x.first, n] } .each do |v|
        apply.push(v.last)
      end
      # Apply takes precedence over remove so a plugin can stop requiring something without preventing another plugin from using it.
      [(@remove - apply) + @forceremove, apply - @forceremove]
    end
    def single_value
      remove, apply = self.multi_value()
      [remove, apply.last]
    end
    def _dump
      @values.each do |v|
        @forceremove.each { |w| puts "        FORCE-REMOVE #{w}" }
        @remove.each      { |w| puts "        REMOVE #{w}" }
        puts "        #{v[0]} #{v[1]}"
      end
    end
  end

  # ---------------------------------------------------------------------------------------------------------------

  # Base class for applying requirements to an object

  class ObjectApplier
    def initialize(code, object, rules)
      @code = code
      @object = object
      @rules = rules
    end
    attr_reader :code, :object, :rules
    def apply(requirement, errors, context)
      requirement.values.each do |key, required_value|
        rule = @rules[key]
        unless rule
          errors << "Unknown key '#{key}' for '#{@code}'"
        else
          @has_changes = true if rule.apply(@object, required_value, context)
        end
      end
    end
    def has_changes?
      !!(@has_changes)
    end
    def mark_as_changed
      @has_changes = true
    end
    def info_for_commit_logging
      ''
    end
    def commit
      if @has_changes
        do_commit()
        KApp.logger.info("Schema requirements: Committed #{@code}#{self.info_for_commit_logging()}")
      end
    end
    def do_commit()
      raise "Not implemented"
    end
    def get_title()
      raise "Not implemented"
    end
    def generate_requirements_definition(type_name, short_defn, context)
      return nil unless @code
      title = self.get_title(@object)
      line1 = "#{type_name} #{@code}"
      line1 << " as #{title.gsub(/\b([a-z])/) { $1.upcase } .gsub(/[^A-Za-z0-9]/,'')}" if title
      return "#{line1}\n" if short_defn
      lines = [line1]
      @rules.each do |key, rule|
        (rule.get_requirements_definition_values(@object) || []).each do |value|
          unless value.nil?
            string = rule.unmap_value(value, context).to_s.gsub(/\s+/,' ') # fix line endings etc
            have_colon = (string =~ / / || KEYS_WITH_COLONS.include?(key))
            lines << "#{key}#{have_colon ? ':' : ''} #{string}"
          end
        end
      end
      lines.join("\n    ")+"\n\n"
    end
  end

  # ---------------------------------------------------------------------------------------------------------------

  # Logic for value application rules

  module SingleValueApply
    def apply(object, required_value, context)
      removes, apply_value = required_value.single_value
      current = value(object)
      if current
        removes.each do |v|
          current = nil if current == map_value(v, context)
        end
      end
      return false unless current == nil && apply_value != nil
      set_value(object, map_value(apply_value, context))
      true
    end
    def get_requirements_definition_values(object)
      [value(object)]
    end
  end

  module MultiValueApply
    def apply(object, required_value, context)
      removes, applies = required_value.multi_value.map { |list| list.map { |v| map_value(v, context) } }
      changed = false
      current_object_values = values(object)
      object_values = current_object_values - removes
      changed = true if object_values.length != current_object_values.length
      # Add the adds, attempting to insert new values into a good place in the list
      last_value = nil
      applies.each do |v|
        unless object_values.include?(v)
          if last_value
            # Insert after last_value, which must be in the array
            object_values = object_values.insert(object_values.find_index(last_value) + 1, v)
          else
            # Can't tell where to put it, just put it at the end
            object_values.push(v)
          end
          changed = true
        end
        last_value = v
      end
      set_values(object, object_values) if changed
      changed
    end
    def get_requirements_definition_values(object)
      values(object)
    end
  end

  # ---------------------------------------------------------------------------------------------------------------

  # Implementation for applying requirements to Ruby objects which have a save! method, eg ActiveRecord.
  # Rules are a map of key to RubyObjectRule and define the allowed attribute keys.
  # Has logic for prefering to leave user values alone unless they're explicitly removed.

  class RubyObjectRule
    def initialize(getter_method, setter_method)
      @getter_method = getter_method
      @setter_method = setter_method
    end
    def map_value(value, context)
      value
    end
    def unmap_value(value, context)
      value
    end
    def value(object)
      object.__send__(@getter_method)
    end
    def set_value(object, value)
      object.__send__(@setter_method, value)
    end
  end

  class RubyObjectRuleValue < RubyObjectRule
    include SingleValueApply
  end

  class RubyObjectRuleMultiString < RubyObjectRule
    include MultiValueApply
    def values(object)
      (self.value(object) || '').to_s.split(/[\r\n]+/)
    end
    def set_values(object, values)
      self.set_value(object, values.join("\n"))
    end
  end

  class ApplyToRubyObject < ObjectApplier
    def do_commit()
      @object.save!
    end
    def get_title(object)
      object.name
    end
  end

  # ---------------------------------------------------------------------------------------------------------------

  # Implementation for applying requirements to store objects

  STORE_OBJECT_STRING_VALUE_MAPPER = Proc.new { |v,context| v.nil? ? nil : KText.new(v) }
  STORE_OBJECT_STRING_VALUE_UNMAPPER = Proc.new { |v,context| v.nil? ? nil : v.to_s }
  STORE_OBJECT_MULTI_STRING_VALUE_MAPPER = Proc.new { |v,context| v.nil? ? nil : v.to_s }
  STORE_OBJECT_MULTI_STRING_VALUE_UNMAPPER = Proc.new { |v,context| v.nil? ? nil : v.to_s }

  class StoreObjectRule
    def initialize(desc, value_mapper = nil, value_unmapper = nil)
      @desc = desc
      @value_mapper = value_mapper || STORE_OBJECT_STRING_VALUE_MAPPER
      @value_unmapper = value_unmapper || STORE_OBJECT_STRING_VALUE_UNMAPPER
    end
    def map_value(value, context)
      @value_mapper.call(value, context)
    end
    def unmap_value(value, context)
      @value_unmapper.call(value, context)
    end
  end

  class StoreObjectRuleSingle < StoreObjectRule
    include SingleValueApply
    def value(object)
      object.first_attr(@desc)
    end
    def set_value(object, value)
      object.delete_attrs!(@desc)
      object.add_attr(value, @desc)
    end
  end

  class StoreObjectRuleMultiBase < StoreObjectRule
    def values(object)
      object.all_attrs(@desc)
    end
    def set_values(object, values)
      object.delete_attrs!(@desc)
      values.each { |v| object.add_attr(v, @desc) }
    end
  end

  class StoreObjectRuleMulti < StoreObjectRuleMultiBase
    include MultiValueApply
  end

  class StoreObjectRuleMultiString < StoreObjectRule
    include MultiValueApply
    def initialize(desc)
      super(desc, STORE_OBJECT_MULTI_STRING_VALUE_MAPPER, STORE_OBJECT_MULTI_STRING_VALUE_UNMAPPER)
    end
    def values(object)
      (object.first_attr(@desc) || '').to_s.split(/[\r\n]+/)
    end
    def set_values(object, values)
      object.delete_attrs!(@desc)
      object.add_attr(values.join("\n"), @desc)
    end
  end

  class ApplyToStoreObject < ObjectApplier
    def info_for_commit_logging
      ", ref #{@object.objref.to_presentation}, version #{@object.version}"
    end
    def do_commit()
      if @object.is_stored?
        KObjectStore.update(@object)
      else
        KObjectStore.create(@object)
      end
    end
    def get_title(object)
      object.first_attr(KConstants::A_TITLE).to_s
    end
  end

  # ---------------------------------------------------------------------------------------------------------------

  # Apply requirements to a schema

  class Context
    def while_committing(applier)
      yield
    end
    def post_commit(applier)
    end
  end

  class Applier
    def initialize(kinds, parser, context)
      @kinds = kinds
      @parser = parser
      @context = context
      @changes = []
      @errors = parser.errors.dup
    end
    attr_reader :parser, :changes, :errors
    def apply
      @parser.apply_templates
      @parser.requirements.each_key do |kind|
        unless @kinds.has_key?(kind)
          @errors << "Unknown kind '#{kind}'"
        end
      end
      @kinds.each do |kind, kind_applier|
        requirements = @parser.requirements[kind]
        requirements.each_value do |requirement|
          next unless requirement.declared_as_non_optional
          object_applier = kind_applier.call(kind, requirement.code, @context)
          if object_applier
            object_applier.apply(requirement, @errors, @context)
            @changes << object_applier if object_applier.has_changes?
          else
            @errors << "Unknown requirement for #{kind} #{requirement.code}"
          end
        end
      end
      self
    end
    def commit
      @context.while_committing(self) do
        @changes.each { |change| change.commit }
      end
      @context.post_commit(self)
      self
    end
    def _dump
      @kinds.each do |kind, kind_applier|
        puts "--- #{kind} ---"
        @parser.requirements[kind].each do |code,requirement|
          puts "  #{kind} #{code}"
          requirement.values.each do |code,value|
            puts "    #{code}"
            value._dump
          end
        end
      end
    end
  end

end
