# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class LabellingPolicy
  include KConstants

  def initialize
  end

  def modify_changes_to_apply_labelling_policy(label_changes, operation, object, obj_previous_version)
    schema = KObjectStore.schema
    type = object.first_attr(A_TYPE)
    type_desc = (schema && type) ? schema.type_descriptor(type) : nil
    # If there's no schema (early in the store initialisation process) or the object doesn't have a
    # type, there's nothing that can be done, so stop now.
    return label_changes unless type_desc

    # Labelling policy applies to create operations only
    if operation == :create
      # Get current labels after modifications so far
      labels = label_changes.change(object.labels)

      # Make sure base labels are applied, unless explicitly removed by something else
      type_desc.base_labels.each do |label|
        unless labels.include?(label) || label_changes.will_remove?(label)
          label_changes.add(label)
        end
      end

      # There must be an applicable label applied, if the set of applicable labels is non-empty
      unless type_desc.applicable_labels.find { |l| labels.include?(l) }
        # and if not, the default applicable label is applied, if there is one
        label_changes.add(type_desc.default_applicable_label) if nil != type_desc.default_applicable_label
      end

      if type_desc.behaviours.include?(O_TYPE_BEHAVIOUR_SELF_LABELLING)
        # When called for pre-object creation checks, objref may not be allocated. Always allocated for real creations.
        if object.objref && !(labels.include?(object.objref))
          label_changes.add(object.objref)
        end
      end
    end

    # Labelling attributes
    # These are considered "relabelling", so need to be adjusted. If the changes aren't allowed,
    # then the object store will throw an exception, so the UI needs to be aware.
    labelling_attributes = type_desc.labelling_attributes
    unless labelling_attributes.empty?
      attr_labels = find_labelling_attributes(object, labelling_attributes)
      label_changes.add(attr_labels)
      if operation != :create
        # Need to remove any attribute labels which changed, unless something else has explicitly added them
        previous_attr_labels = find_labelling_attributes(obj_previous_version, labelling_attributes)
        (previous_attr_labels - attr_labels).each do |label|
          unless label_changes.will_add?(label)
            label_changes.remove(label)
          end
        end
      end
    end

    label_changes
  end

  def find_labelling_attributes(object, labelling_attributes)
    labels_from_attrs = []
    object.each do |value,desc,q|
      if labelling_attributes.include?(desc) && value.kind_of?(KObjRef)
        # All parents of the objref need to be included too
        labels_from_attrs.concat KObjectStore.expand_objref_into_full_parent_path(value)
      end
    end
    labels_from_attrs
  end

end
