# frozen_string_literal: true

# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KObjectLoader
  include KConstants

  def self.load_from_file(filename, object_handler = nil)
    load_from_string(File.new(filename).read, object_handler)
  end

  def self.load_store_initialisation
    load_from_string(STORE_INITIALISATION)
  end

  def self.load_from_string(str, object_handler = nil)
    lines = str.split(/\n/)
    lines << ''   # make sure there's always a blank line at the end

    schema = KObjectStore.schema

    # Build ruby code from the definitions.
    # Maintain line numbers for easier debugging.
    output = []
    current_object_number = 0
    current_object_ref = nil
    literal = nil
    lines.each do |line|
      o = ''

      if literal != nil
        # literal line output for here document
        o = line
        literal = nil if line == literal
      else
        # Normal line... remove comments first
        line = line.gsub(/(^|\s+)#.+$/,'')

        # Process line
        if line =~ /^obj\s+(\[[^\]]*\])\s+(.+)\s*/
          # starts new object
          raise "Must be blank line between objects" if current_object_ref != nil
          labels = $1
          current_object_ref = $2
          o = "obj#{current_object_number} = KObject.new(#{labels})"
        elsif line =~ /^[A-Z].*=/
          # defines constant, let past without modification
          o = line
        elsif line =~ /^\s+([\w\/-]+)\s+(.+)\s*$/
          # define attribute
          desc = $1
          value = $2
          raise "Can't use aliased attribute when loading objects" if desc =~ /^AA_/
          desc_and_qual = if desc =~ /\//
            d, q = desc.split '/'
            # translate objrefs?
            d = KObjRef.from_presentation(d).to_desc if d =~ /-/
            q = KObjRef.from_presentation(q).to_desc if q =~ /-/
            # Make into a nice string
            "#{d}, #{q}"
          else
            # just the desc, no qualifier
            (desc =~ KObjRef::VALIDATE_REGEXP) ? KObjRef.from_presentation(desc).to_desc : desc
          end
          # Modify values?
          if value =~ /^\(/
            value = 'KObjRef.new' + value
          elsif value =~ /^(A|AA|Q)_/   # attributes and qualifiers
            # This only works for core objects
            value = "KObjRef.new(#{value})"
          elsif value =~ /^T\(/
            value.gsub!(/^T/,'KText.new')
          end
          # Look out for literal text in data
          literal = $1 if value =~ /\<\<(\w+),?\s*/
          o = "obj#{current_object_number}.add_attr(#{value}, #{desc_and_qual})"
        elsif line !~ /\S/
          if current_object_ref != nil
            # Make any necessary transforms
            if current_object_ref =~ /^O_/ || current_object_ref =~ /^objref_plus/
              current_object_ref = "#{current_object_ref}.obj_id"
            elsif current_object_ref =~ /^(A|AA|Q)_/
              current_object_ref = "#{current_object_ref}"
            end
            o = "object_handler.object(obj#{current_object_number}, #{current_object_ref})"
          end
          current_object_ref = nil
          current_object_number += 1
        else
          raise "Bad input line: #{line}"
        end
      end

      output << o
    end

    code = output.join "\n"

    object_handler ||= DefaultObjectHandler.new
    object_handler.on_start

    # Run the code in the context of this module, while pausing schema reloads for efficiency
    KObjectStore.store.delay_schema_reload_during do
      eval(code, binding)
    end

    object_handler.on_finish
  end

  # Default object handler, which just creates objects
  class DefaultObjectHandler
    def on_start
      @object_count = 0
    end
    def object(obj, obj_id = nil)
      @object_count += 1
      KObjectStore.create(obj, nil, obj_id)
    end
    def on_finish
    end
  end

  # Utility function
  def self.objref_plus(objref, n)
    KObjRef.new(objref.obj_id + n)
  end

  # Define the very basic objects to initialise the store
  STORE_INITIALISATION = <<__INIT

obj [O_LABEL_STRUCTURE] O_STORE_OPTIONS
  A_TITLE   "$ Store Options"
  A_OPTION  "ktextpersonname_western_sortas=last_first"

obj [O_LABEL_STRUCTURE] O_TYPE_ATTR_DESC
  A_TITLE   "$ Attribute Descriptor Type"

obj [O_LABEL_STRUCTURE] O_TYPE_QUALIFIER_DESC
  A_TITLE   "$ Attribute Qualifier Type"

obj [O_LABEL_STRUCTURE] O_TYPE_RESTRICTION
  A_TITLE   "$ Restriction Type"

obj [O_LABEL_STRUCTURE] Q_NULL
  A_TITLE   "$ Null Qualifier"
  A_CODE    KIdentifierConfigurationName.new("std:qualifier:null")

__INIT
end

