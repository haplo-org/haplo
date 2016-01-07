# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Annotations module, enable in base class with "extend Ingredient::Annotations"
module Ingredient
  module Annotations
    # Annotate the class
    def annotate_class(annotation_name, value)
      _annotation_storage(:@_annotated_class)[annotation_name] = value
    end

    # Get a class annotation
    def annotation_get_class(annotation_name)
      c = self.instance_variable_get(:@_annotated_class)
      (c == nil) ? nil : c[annotation_name]
    end

    # Annotate the next method defined
    def annotate_method(annotation_name, value)
      _annotation_storage(:@_annotated_next_method)[annotation_name] = value
    end

    # Get a method annotation
    def annotation_get(method_name, annotation_name)
      m = self.instance_variable_get(:@_annotated_methods)
      (m == nil) ? nil : m[method_name][annotation_name]
    end

  private
    # Magic method to make this work
    def method_added(method_name)
      a = self.instance_variable_get(:@_annotated_next_method)
      if a != nil
        _annotation_storage(:@_annotated_methods,{})[method_name] = a
        self.instance_variable_set(:@_annotated_next_method, nil)
      end
      super
    end

    # Store data in the class variable
    def _annotation_storage(name, default = nil)
      a = self.instance_variable_get(name)
      if a == nil
        a = Hash.new(default)
        self.instance_variable_set(name, a)
      end
      a
    end
  end
end
