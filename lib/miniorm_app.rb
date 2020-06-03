# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Column definitions for app specific object types

module MiniORMAppColumns

  class ObjRefColumn < MiniORM::IntColumn
    _column :objref
    def set_value_in_statement(statement, index, value)
      super(statement, index, value.obj_id)
    end
    def get_value_from_resultset(results, index)
      v = super
      v.nil? ? nil : KObjRef.new(v)
    end
    def generate_extra_record_code
      <<__E
      def #{self.name_str}_obj_id
        r = self.#{self.name_str}; r ? r.obj_id : nil
      end
      def #{self.name_str}_obj_id_set(obj_id)
        self.#{self.name_str} = obj_id.nil? ? nil : KObjRef.new(obj_id)
      end
__E
    end
  end

  class LabelListColumn < MiniORM::IntArrayColumn
    _column :labellist
    def set_value_in_statement(statement, index, value)
      super(statement, index, value._to_internal)
    end
    def get_value_from_resultset(results, index)
      v = super
      v.nil? ? nil : KLabelList.new(v)
    end
  end

end


# Create tags columns in tables

class MiniORM::Table

  def tags_column_and_where_clauses
    self.column :hstore_as_text, :tags, nullable:true
    self.where :tag, '(tags -> ?) = ?', :text, :text
    self.where :tag_is_empty_string_or_null, "COALESCE((tags -> ?),'') = ''", :text
  end

end
