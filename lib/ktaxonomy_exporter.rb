# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class KTaxonomyExporter
  include KConstants

  def self.cmd_export_to_file(app_id, root_ref_str, filename)
    KApp.in_application(app_id) do
      exporter = KTaxonomyExporter.new(KObjRef.from_presentation(root_ref_str))
      exporter.export(filename)
    end
  end

  def initialize(root_ref)
    @root_ref = root_ref
    raise "Bad root ref for taxonomy exporter" unless @root_ref.kind_of?(KObjRef)
  end

  def export(filename)
    # Fetch all members of taxonomy
    results = KObjectStore.query_and.link(@root_ref, A_PARENT).execute(:all, :title) # sort by title for nice ordering in results
    # Run through and make map of parent to terms
    lookup = Hash.new
    results.each do |obj|
      parent = obj.first_attr(A_PARENT)
      raise "Bad logic" unless parent != nil
      lookup[parent] ||= []
      lookup[parent] << obj
    end
    # Open file and export
    File.open(filename, "w") do |file|
      # Start at the root, and export entries
      export_level(0, @root_ref, lookup, file)
    end
  end

  def export_level(level, parent_ref, lookup, file)
    objects = lookup[parent_ref]
    return unless objects != nil
    indent = "\t" * level
    objects.each do |obj|
      # Check object
      need_to_warn = false
      obj.each() do |v,desc,q|
        need_to_warn = true if desc != A_TYPE && desc != A_PARENT && desc != A_TITLE
      end
      puts "WARNING: Term #{obj.objref.to_presentation} has extra fields which will not be exported" if need_to_warn
      # Export object
      v = []
      obj.each(A_TITLE) do |value,d,q|
        v << value.to_s.gsub(/\s/,' ')
      end
      file.write("#{indent}#{v.join(" / ")}\n")
      export_level(level + 1, obj.objref, lookup, file)
    end
  end

end
