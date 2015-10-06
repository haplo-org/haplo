# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class UserPolicy

  def find_all_visible_taxonomies(write_permission = false)
    query = KObjectStore.query_and
    n = query.not
      types_clause = n.or
      KObjectStore.schema.hierarchical_classification_types().each { |objref| types_clause.link_exact(objref, KConstants::A_TYPE) }
      n.link_to_any(KConstants::A_PARENT)
    results = query.execute(:all, :title)
    if write_permission
      results = results.select do |obj|
        @user.policy.has_permission?(:update, obj)
      end
    end
    results
  end

  def can_edit_at_least_one_taxonomy?
    (find_all_visible_taxonomies(true).length > 0)
  end

end

