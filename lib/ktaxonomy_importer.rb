# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KTaxonomyImporter
  include KConstants

  def self.cmd_import_file(app_id, filename, name_or_ref, term_type)
    app_id = app_id.to_i
    raise "Bad taxonomy name" if name.length == 0
    # TODO: Check the taxonomy doesn't already exist

    # Term type, if given
    term_type = (term_type != nil && term_type != '') ? KObjRef.from_presentation(term_type) : nil

    KApp.in_application(app_id) do
      importer = KTaxonomyImporter.new(KObjectStore.store, term_type)
      importer.import_file_tab_hierarchy(filename, name_or_ref)
    end
  end

  def initialize(store, term_type = nil)
    @store = store
    @term_type = term_type || O_TYPE_TAXONOMY_TERM
  end

  # Tabs indicate hierarchy, followed by a sequence of characters for the titles, followed by any number of alternatives (/a/b)
  def import_file_tab_hierarchy(filename, name_or_ref)
    parents = []
    # Create the root, or use an existing root?
    taxonomy_root = nil
    if name_or_ref =~ KObjRef::VALIDATE_REGEXP
      taxonomy_root = KObjectStore.read(KObjRef.from_presentation(name_or_ref))
      raise "Couldn't find supplied taxonomy root" unless taxonomy_root
    else
      # Create root, store as first
      taxonomy_root = KObject.new()
      taxonomy_root.add_attr(@term_type, A_TYPE)
      taxonomy_root.add_attr(name_or_ref, A_TITLE)
      @store.create(taxonomy_root)
    end
    # Store ref as top level parent
    parents.push(taxonomy_root.objref)
    # Create terms
    File.open(filename) do |file|
      file.each do |line|
        next unless line =~ /\A(\t*)(\S.*)[\r\n]*\z/
        depth = $1.length
        titles = $2.split(/\s+\/\s+/)
        # Create object
        term = KObject.new()
        term.add_attr(@term_type, A_TYPE)
        term.add_attr(parents[depth], A_PARENT)
        term.add_attr(titles.shift, A_TITLE)
        titles.each { |t| term.add_attr(t, A_TITLE, Q_ALTERNATIVE) }
        @store.create(term)
        # Store objref for parents (+1 because root is zero, but first level terms have zero indent)
        parents[depth+1] = term.objref
      end
    end
    taxonomy_root.objref
  end

end
