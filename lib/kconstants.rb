# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# This file defines the basic constants for generic object store use

# Javascript code also needs to use these, do
#    ruby lib/tasks/update_javascript_constants.rb
# to update the kconstants.js file.

module KConstants

  # Reserved object IDs
  MAX_RESERVED_OBJID        = 524288

  # Data types
  #  -- call k_typecode on an object to find it's type (see below)
  T_OBJREF                  = 0
  T_TYPEREF                 = 1
  T_INTEGER                 = 2
  T_NUMBER                  = 3
  T_DATETIME                = 4
  T_BOOLEAN                 = 5
  T_BLOB                    = 6
  # 7 was T_FOREIGN_DATA
  # Gap for future non-string types
  T_TEXT__MIN               = 16                # All types 16 or above are string types
  T_TEXT                    = T_TEXT__MIN + 0
  T_TEXT__APP_MIN           = T_TEXT__MIN + 8   # Application string types start here

  DATA_TYPE_NAMES = {
      T_OBJREF => 'Link to other object',
      T_TYPEREF => 'Type reference',
      T_INTEGER => 'Integer',
      T_NUMBER => 'Number',
      T_DATETIME => 'Date and time',
      T_BOOLEAN => 'Boolean',
      T_BLOB => 'BLOB'
    }

  # Special labels used by core object store code
  O_LABEL_UNLABELLED        = KObjRef.new(100)  # Not labelled with any other label
  O_LABEL_DELETED           = KObjRef.new(101)  # Object is deleted

  # Core store attribute descriptors
  A_OPTION                  = 199     # for O_STORE_OPTIONS
  # 200 was A_CREATION_TIME_REPRESENTED
  A_PARENT                  = 201     # Link to Parent object (for tree definition)
  # 202 was A_CONTAINER
  # 203 was A_FOREIGN_DATA
  # Other attribute descritors used by the store
  A_TYPE                    = 210     # Link to Object Type definition, also Dublin Core
  A_TITLE                   = 211     # As Dublin Core
  A_CODE                    = 2000
  A_ATTR_SHORT_NAME         = 2010    # TODO: Rename A_ATTR_SHORT_NAME as it's also used for type short names
  A_ATTR_DATA_TYPE          = 2011
  A_RELEVANCY_WEIGHT        = 2012    # Integer, multiplation factor * 1000 (RELEVANCY_WEIGHT_MULTIPLER)
  RELEVANCY_WEIGHT_MULTIPLER = 1000.0
  # 2013 was A_META_INCLUSION_SPEC
  A_TERM_INCLUSION_SPEC     = 2014
  A_ATTR_CONTAINED          = 2019

  # Restrictions
  A_RESTRICTION_TYPE        = 2020
  A_RESTRICTION_LABEL       = 2021
  A_RESTRICTION_ATTR_RESTRICTED = 2022
  A_RESTRICTION_ATTR_READ_ONLY  = 2023

  # Qualifiers
  Q_NULL                    = 0

  # ID base values for application objects
  BASE_APP_LABEL_DEFINITIONS= 7500
  BASE_APP_TYPE_DEFINITIONS = 8000      # App defined object definitions go here
  BASE_APP_WELL_KNOWN_OBJS  = 12000     # App defined well known objects after here

  # Well known objects
  O_STORE_OPTIONS           = KObjRef.new(2)
  O_TYPE_ATTR_DESC          = KObjRef.new(6)
  O_TYPE_QUALIFIER_DESC     = KObjRef.new(7)
  # KObjRef.new(8) was O_TYPE_SECTION_DESC
  O_TYPE_RESTRICTION        = KObjRef.new(9)
end

# Utility functions for Object
class Object
  def k_typecode
    raise "Class #{self.class} is not a valid object for storage in a KObject"
  end
  def k_is_string_type? # actually string or identifier
    k_typecode >= KConstants::T_TEXT__MIN
  end
end

# Add k_typecode to built in objects
class Fixnum
  def k_typecode; KConstants::T_INTEGER end
end
class Bignum
  def k_typecode; KConstants::T_INTEGER end
end
class Float
  def k_typecode; KConstants::T_NUMBER end
end
class FalseClass
  def k_typecode; KConstants::T_BOOLEAN end
end
class TrueClass
  def k_typecode; KConstants::T_BOOLEAN end
end

# And to project fundamental types to avoid loops in requires
class KObjRef
  def k_typecode; KConstants::T_OBJREF end
end

# Look up typecodes
module KConstants
  def self.k_typecode_to_text(typecode)
    DATA_TYPE_NAMES[typecode] || KText.get_typecode_info(typecode).name
  end
end


