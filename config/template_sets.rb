# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



module Templates

  module Application
    Ingredient::Templates.load(self,
      "#{KFRAMEWORK_ROOT}/app/views",
      'data_for_template',
      :render_template
    )
  end

  module NativePlugins
    Ingredient::Templates.load(self,
      "#{KFRAMEWORK_ROOT}/app/plugins",
      'data_for_template',
      :render_template
    )
  end

  module RenderObj
    include KConstants
    Ingredient::Templates.load(self,
      "#{KFRAMEWORK_ROOT}/app/render_obj",
      'obj,type_desc,options,recursion_limit,content_for_layout',
      :obj_render
    )
  end

end

