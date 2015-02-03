# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KLabelsActiveRecord

  # Getter
  def labels
    l = read_attribute('labels')
    (l == nil) ? nil : (@_decoded_labels ||= KLabelList._from_sql_value(l))
  end

  # Setter
  def labels=(new_labels)
    if new_labels == nil
      write_attribute('labels', nil)
    else
      raise "Labels should be KLabelList" unless new_labels.kind_of? KLabelList
      write_attribute('labels', new_labels._to_sql_value)
    end
    @_decoded_labels = new_labels
  end

  # ActiveRecord callback to make sure every entry is labelled properly
  def klabels_check_labelling
    current_labels = self.labels
    if current_labels.nil? || current_labels.empty?
      # If nil or empty, give it the unlabelled label instead
      self.labels = KLabelList.new([KConstants::O_LABEL_UNLABELLED])
    end
  end

  module ClassMethods
    def where_labels_permit(operation, label_statements)
      raise "where_labels_permit requires a KLabelStatements" unless label_statements.kind_of? KLabelStatements
      self.where([label_statements._sql_condition(operation, "labels")])
    end
  end

  def self.implement_labels_attribute(klass)
    klass.module_eval <<__E
      include KLabelsActiveRecord
      extend KLabelsActiveRecord::ClassMethods
      before_save :klabels_check_labelling
__E
  end

end
