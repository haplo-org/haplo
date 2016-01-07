# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# This handles aliased attributes, turning objects into displayable and/or editable structures

# This is in the global namespace because it's by other things. This is just a handy place to define it.
DescriptorAndAttrs = Struct.new(
    :descriptor,    # might be normal or aliased attribute descriptor
    :attributes     # array of attributes, as [value,desc,qualifier] triples
  )

module KAttrAlias
  include KConstants

  # Takes an object, and an optional block, and transforms it into the user displayable format
  # using the aliased definitions where appropraite. Returns array of DescriptorAndAttrs
  # yields value,desc,qualifier,is_aliased
  # Takes the allow_aliasing parameter so aliasing can be switched off easily without
  # consumers of the output having to write two versions.
  def self.attr_aliasing_transform(obj, schema = nil, allow_aliasing = true)
    transformed = Array.new
    schema ||= obj.store.schema

    # Get the object's type descriptor to find the list of attributes, which may include aliases
    type_objref = obj.first_attr(A_TYPE)
    return [] if type_objref == nil
    type_descriptor = schema.type_descriptor(type_objref)
    attributes = type_descriptor ? type_descriptor.attributes : []

    # Build an initial list of all the attributes, with a lookup
    transformed_lookup = Hash.new
    aliases_on = Hash.new         # non-aliased desc -> array of alias type descriptors
    attributes.each do |desc|
      descriptor = schema.attribute_descriptor(desc)
      alias_descriptor = nil
      if descriptor == nil
        # Is it aliased?
        alias_descriptor = schema.aliased_attribute_descriptor(desc)
        descriptor = alias_descriptor
      end
      if descriptor != nil && !transformed_lookup.has_key?(desc)
        toa = DescriptorAndAttrs.new(descriptor, Array.new)
        transformed << toa
        transformed_lookup[desc] = toa
        # Alias lookups
        if alias_descriptor != nil
          aliases_on[alias_descriptor.alias_of] ||= Array.new
          aliases_on[alias_descriptor.alias_of] << toa
        end
      end
    end

    # Now...
    #    transformed contains empty DescriptorAndAttrs for non-aliased and aliased attributes
    #    transformed_lookup looks these up by desc
    #    aliases_on looks up arrays of DescriptorAndAttrs on the original attribute

    # Go through the object and sort the attributes
    obj.each do |value,desc,qual|
      # Make sure this is required
      if !(block_given?) || yield(value,desc,qual,false)  # not aliased
        # Might it be aliased?
        did_alias = false
        potential_aliases = aliases_on[desc]
        if potential_aliases != nil && allow_aliasing
          # Run through the aliases, see if any match
          best_alias = nil
          best_score = -1
          potential_aliases.each do |toa|
            match = true
            score = 0
            # Check qualifier (return might be empty array for not specified)
            if toa.descriptor.specified_qualifiers.include?(qual)
              score += 1
            else
              match = false unless toa.descriptor.specified_qualifiers.empty?
            end
            # Check type (return might be nil not specified)
            if toa.descriptor.specified_data_type == value.k_typecode
              score += 1
            else
              match = false unless toa.descriptor.specified_data_type == nil
            end
            # Check linked types (might be empty for not specified)
            linkedtypes = toa.descriptor.specified_linked_types_with_children
            if !(linkedtypes.empty?) && value.class == KObjRef
              linked_obj = obj.store.read(value)
              if linked_obj != nil && linkedtypes.include?(linked_obj.first_attr(KConstants::A_TYPE))
                score += 1
              else
                match = false
              end
            end
            # Best score? (use > to get the first matching alias for a descriptor)
            if match && score > best_score
              best_alias = toa
              best_score = score
            end
          end
          # Do the alias (checking with caller)
          if best_alias != nil
            did_alias = true
            # If the aliased specified qualifiers only contains a single qualifer, use Q_NULL instead
            sq = best_alias.descriptor.specified_qualifiers
            aliased_qual = (sq.length == 1) ? Q_NULL : qual
            # Check with called that the alias should be included
            if !(block_given?) || yield(value,best_alias.descriptor.desc,aliased_qual,true)  # aliased
              best_alias.attributes << [value,best_alias.descriptor.desc,aliased_qual]
            end
          end
        end
        unless did_alias
          # Not aliased; add normally
          toa = transformed_lookup[desc]
          if toa == nil
            # Need to make a new one
            descriptor = schema.attribute_descriptor(desc)
            if descriptor != nil
              toa = DescriptorAndAttrs.new(descriptor, Array.new)
              transformed << toa
              transformed_lookup[desc] = toa
            end
          end
          toa.attributes << [value,desc,qual] if toa != nil
        end
      end
    end

    # Remove the A_TYPE attribute if there is a single type attribute of a root type
    type_attr = transformed_lookup[A_TYPE]
    if type_attr == nil && aliases_on.has_key?(A_TYPE)
      # Use the first A_TYPE alias instead
      type_attr = aliases_on[A_TYPE].first
    end
    if type_attr != nil
      if type_attr.attributes.length == 1
        # Eligiable for removal, see if it's a root type
        type_desc = schema.type_descriptor(type_attr.attributes.first.first)
        if type_desc != nil && type_desc.parent_type == nil
          # It's a root type; remove this attribute from the display
          if type_descriptor.attributes.include?(type_attr.descriptor.desc)
            # Type wants this to be displayed, so set it to the empty array
            type_attr.attributes = []
          else
            # Not supposed to be displayed, remove the entry entirely
            transformed.delete(type_attr)
          end
        end
      end
    end

    transformed
  end

end

