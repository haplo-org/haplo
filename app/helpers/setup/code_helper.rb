# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module Setup_CodeHelper

  def code_show_in_table(code)
    r = '<tr><th>API code</th><td>'.dup
    code = code.to_s if code
    if code && code.length > 0
      r << %Q!<span class="z__management_code_text">#{h(code)}</span>!
    else
      r << "<i>(not used)</i>"
    end
    r << '</td></tr>'
    r
  end

  def code_value_edit_ui(code, input_name = "code")
    has_code = (code || "").to_s.length > 0
    code_value = params['code'] || code
    if KApp.global_bool(:schema_api_codes_locked) && has_code
      # If API codes are locked and it has a code, then don't allow it to be edited. But purely advisory, as it's still sent a hidden field.
      %Q!<p>API code<br><span class="z__management_code_text">#{h(code.to_s)}</span><input type="hidden" name="#{input_name}" value="#{h(code_value.to_s)}">!
    else
      %Q!<p>API code<br><input class="z__management_code_edit" name="#{input_name}" value="#{h(code_value.to_s)}" size="32"> <span class="z__management_code_warning">Warning: required by plugins</span></p>!
    end
  end

  def code_set_edited_value_in_object(obj)
    obj.delete_attrs!(KConstants::A_CODE)
    code = params['code']
    if code
      code = code.gsub(/[^a-z0-9:-]/,'')
      if code && code.length > 0 && code.length < 256
        obj.add_attr(KIdentifierConfigurationName.new(code), KConstants::A_CODE)
      end
    end
  end

end
