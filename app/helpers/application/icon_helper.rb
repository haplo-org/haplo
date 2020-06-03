# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.




# Helpers for generating HTML for the little type icons.

module Application_IconHelper

  # ---------------------------------------------
  # Object type icons

  ICON_SIZE_TO_CLASS = {
    :micro => 'z__icon_micro',
    :small => 'z__icon_small',
    :medium => 'z__icon_medium',
    :large => 'z__icon_large'
  }

  ICON_COMPONENT_CLASSES = {
    '0' => 'z__icon_colour0',
    '1' => 'z__icon_colour1',
    '2' => 'z__icon_colour2',
    '3' => 'z__icon_colour3',
    '4' => 'z__icon_colour4',
    '5' => 'z__icon_colour5',
    '6' => 'z__icon_colour6',
    '7' => 'z__icon_colour7',
    'a' => 'z__icon_component_position_top_left',
    'b' => 'z__icon_component_position_top_right',
    'c' => 'z__icon_component_position_centre',
    'd' => 'z__icon_component_position_bottom_left',
    'e' => 'z__icon_component_position_bottom_right',
    'f' => 'z__icon_component_position_full',
    'n' => 'z__icon_normal_character',
    's' => 'z__icon_is_system_action',
    'x' => 'z__icon_opacity25',
    'y' => 'z__icon_opacity50',
    'z' => 'z__icon_opacity75'
  }

  # Generic icon definition
  ICON_GENERIC = 'E201,1,f'
  # Icons used as the default when setting up schema
  ICON_DEFAULT_LIST_OBJECT = 'E501,1,f'
  # Icons for UI
  ICON_SPECIAL_RECENT_OBJECT_HAS_FILES = 'E201,1,f,y'
  ICON_SPECIAL_LINKED_ITEMS = 'E008,1,f'
  ICON_SPECIAL_LINKED_ITEMS_SELECTED = 'E525,1,f E008,1,f'
  ICON_SPECIAL_RECENT_VERSION = 'E525,1,f,s E526,2,c'
  ICON_SPECIAL_RECENT_ERASE_OBJ = 'E525,1,f,s E413,2,c'
  ICON_SPECIAL_HAS_FILES = 'E201,1,f,y E227,0,c'

  # Build Regexp for validating icon definitions
  icon_part_regexp = "[0-9a-fA-F]{4}(\,[#{ICON_COMPONENT_CLASSES.keys.join('')}])+"
  VALIDATE_ICON_REGEXP = Regexp.new("\\A#{icon_part_regexp}( #{icon_part_regexp})*\\z")

  # ---------------------------------------------
  # Icon rendering

  def html_for_icon(icon_description, icon_size, text = nil)
    icon_description = ICON_GENERIC unless icon_description.is_a?(String) && icon_description.length > 0
    icon_components = icon_description.split(' ').map { |c|
      instructions = c.split(',')
      codepoint = instructions.shift
      %Q!<span class="#{instructions.map { |k| ICON_COMPONENT_CLASSES[k] } .join(' ')}">&#x#{codepoint};</span>!
    }. join

    # TODO: Should title be displayed on all icons? Needed for the linked item icons row for hover titles.
    title = text ? %Q! title="#{text}"! : ''

    icon_class = ICON_SIZE_TO_CLASS[icon_size]
    raise "Bad icon_size #{icon_size}" unless icon_class
    %Q!<span class="z__icon #{icon_class}"#{title}>#{icon_components}</span>!
  end

  # ---------------------------------------------
  # Icon designer UI

  def control_icon_designer(dom_id, icon_description = ICON_GENERIC)
    client_side_resources(:icon_designer)
    %Q!<div class="z__icon_designer" id="#{dom_id}" data-defn="#{ERB::Util.h(icon_description)}"></div>!
  end

  def icon_is_valid_description?(icon_description)
    !!(icon_description.kind_of?(String) && (icon_description =~ VALIDATE_ICON_REGEXP))
  end

  # ---------------------------------------------
  # File type icons

  def img_tag_for_mime_type(mime_type, extra_html_attrs = nil)
    %Q!<img src="/images/ft/#{(mime_type == nil) ? 'generic' : KMIMETypes.type_icon(mime_type)}.gif" width="16" height="16" alt=""#{extra_html_attrs}>!
  end

end

