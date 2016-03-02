# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# This file defines the the constants for the K'HQ application

module KConstants

  # String/Identifier typecodes
  T_TEXT_PARAGRAPH              = T_TEXT__APP_MIN + 0
  T_TEXT_DOCUMENT               = T_TEXT__APP_MIN + 1
  # T_TEXT__APP_MIN + 2 was T_TEXT_MARC21
  T_IDENTIFIER_FILE             = T_TEXT__APP_MIN + 3
  T_IDENTIFIER_ISBN             = T_TEXT__APP_MIN + 4
  T_IDENTIFIER_EMAIL_ADDRESS    = T_TEXT__APP_MIN + 5
  T_IDENTIFIER_URL              = T_TEXT__APP_MIN + 6
  T_IDENTIFIER_POSTCODE         = T_TEXT__APP_MIN + 7
  T_IDENTIFIER_TELEPHONE_NUMBER = T_TEXT__APP_MIN + 8
  T_TEXT_MULTILINE              = T_TEXT__APP_MIN + 9
  # T_TEXT__APP_MIN + 10 was T_IDENTIFIER_CHOICE
  T_TEXT_PERSON_NAME            = T_TEXT__APP_MIN + 11
  T_IDENTIFIER_POSTAL_ADDRESS   = T_TEXT__APP_MIN + 12

  T_IDENTIFIER_CONFIGURATION_NAME = T_TEXT__APP_MIN + 16

  T_TEXT_PLUGIN_DEFINED         = T_TEXT__APP_MIN + 40

  # Psuedo types -- used by javascript editor
  T_PSEUDO_TAXONOMY_OBJREF      = -1
  T_PSEUDO_PARENT_OBJREF        = -8
  T_PSEUDO_TYPE_OBJREF          = -9
  # NOTE: keditor.js also defines pseudo types - make sure new constants don't clash

  # Default options shared with javascript editor
  DEFAULT_UI_OPTIONS_DATETIME   = 'd,n,n,n,n'  # sync changes with db/app_dc_override.objects
  DEFAULT_UI_OPTIONS_PERSON_NAME  = 'w,w=tfl,L=lf,e=lf'

  # Dublin Core elements
  # A_TYPE + A_TITLE are used by the store, and defined in kconstants.rb
  # A_TYPE                      = 210
  # A_TITLE                     = 211
  A_CREATOR                     = 212
  A_AUTHOR                      = A_CREATOR
  A_SUBJECT                     = 213
  A_DESCRIPTION                 = 214
  A_PUBLISHER                   = 215
  A_CONTRIBUTOR                 = 216
  A_DATE                        = 217
  A_FORMAT                      = 218
  A_IDENTIFIER                  = 219
  A_SOURCE                      = 220
  A_LANGUAGE                    = 221
  A_RELATION                    = 222
  A_COVERAGE                    = 223
  A_RIGHTS                      = 224
  # (not all these may be used by a schema)

  # ONEIS schema attributes -- data
  A_URL                         = 400
  A_EMAIL_ADDRESS               = 401
  A_ISBN                        = 402
  A_JOB_TITLE                   = 403
  A_ADDRESS                     = 404
  A_TELEPHONE_NUMBER            = 405

  # ONEIS schema attributes -- links to object types
  A_PROJECT                     = 500
  A_EVENT                       = 501

  # ONEIS schema attributes -- links to object describing relationship
  A_CLIENT                      = 600
  A_WORKS_FOR                   = 601
  A_ATTENDEE                    = 602
  A_RELATIONSHIP_MANAGER        = 603
  A_PROJECT_LEADER              = 604
  A_PROJECT_TEAM                = 605
  A_ORGANISED_BY                = 606
  A_PURCHASED_FROM              = 607
  A_MANUFACTURER                = 608
  A_PARTICIPANT                 = 609
  A_SPEAKER                     = 610
  A_VENUE                       = 611
  A_FIRST_CONTACT_VIA           = 612
  A_MEMBER_OF                   = 613

  # Default search by field attributes - system can be configured to alter this
  DEFAULT_SEARCH_BY_FIELDS_ATTRS = [A_TITLE, A_SUBJECT, A_CLIENT, A_PROJECT]

  # Aliased attributes
  AA_DATE_AND_TIME              = 806
  AA_YEAR                       = 807
  # Aliased attributes for people
  AA_NAME                       = 810     # for A_TITLE, used for renaming fields for people
  AA_EXPERTISE                  = 811     # for A_SUBJECT, for people
  AA_CONTACT_CATEGORY2          = 815     # alias of A_TYPE (has 2 suffix to avoid confusion with old schema)
  AA_ORGANISATION_NAME          = 816
  AA_PARENT_ORGANISATION        = 817

  # Relationships
  AA_PARTICIPATING_ORGANISATION = 830

  # Dublin Core qualifiers
  Q_ALTERNATIVE                 = 1000
  Q_TABLE_OF_CONTENTS           = 1001
  Q_ABSTRACT                    = 1002
  Q_CREATED                     = 1003
  Q_VALID                       = 1004
  Q_AVAILABLE                   = 1005
  Q_ISSUED                      = 1006
  Q_MODIFIED                    = 1007
  Q_DATE_ACCEPTED               = 1008
  Q_DATE_COPYRIGHTED            = 1009
  Q_DATE_SUBMITTED              = 1010
  Q_EXTENT                      = 1011
  Q_MEDIUM                      = 1012
  Q_IS_VERSION_OF               = 1013
  Q_HAS_VERSION                 = 1014
  Q_IS_REPLACED_BY              = 1015
  Q_REPLACES                    = 1016
  Q_IS_REQUIRED_BY              = 1017
  Q_REQUIRES                    = 1018
  Q_IS_PART_OF                  = 1019
  Q_HAS_PART                    = 1020
  Q_IS_REFERENCED_BY            = 1021
  Q_REFERENCES                  = 1022
  Q_IS_FORMAT_OF                = 1023
  Q_HAS_FORMAT                  = 1024
  Q_CONFORMS_TO                 = 1025
  Q_SPATIAL                     = 1026
  Q_TEMPORAL                    = 1027
  Q_AUDIENCE                    = 1028
  Q_ACCRUAL_METHOD              = 1029
  Q_ACCRUAL_PERIODICITY         = 1030
  Q_ACCRUAL_POLICY              = 1031
  Q_INSTRUCTIONAL_METHOD        = 1032
  Q_PROVENANCE                  = 1033
  Q_RIGHTS_HOLDER               = 1034
  Q_ACCESS_RIGHTS               = 1035
  Q_LICENSE                     = 1036
  Q_BIBLIOGRAPHIC_CITATION      = 1037

  # Application qualifiers
  # Phone number / postal address qualifiers
  Q_OFFICE                      = 1900
  Q_MOBILE                      = 1901
  Q_HOME                        = 1902
  Q_PERSONAL                    = 1903
  Q_FAX                         = 1904
  Q_SWITCHBOARD                 = 1905
  Q_CORRESPONDENCE              = 1906

  # Generic style extensions to DC
  Q_PHYSICAL                    = 1910

  # Other
  Q_ROLE                        = 1920
  Q_NICKNAME                    = 1921

  # d2100 - d4999: application use
  # Application data (starting at 2100)

  # Types
  A_RELEVANT_ATTR               = 2100      # Attributes linked are displayed by default in the editor
  A_RENDER_TYPE_NAME            = 2101
  A_RENDER_ICON                 = 2102
  # 2103 was A_DISPLAY_LINKED_WITH_CAPTION
  A_RENDER_CATEGORY             = 2104      # Which category the type falls in; controls background colour in search results.
  # 2105 was A_TYPE_CREATE_DEFAULT_SECTION
  # 2106 was A_TYPE_CREATE_ALLOWED_SECTION
  A_TYPE_CREATION_UI_POSITION   = 2107      # Where the new type offer will be displayed, values of TYPEUIPOS_*
  A_TYPE_BEHAVIOUR              = 2108      # Links to any type behaviours which apply to this type
  A_RELEVANT_ATTR_REMOVE        = 2109      # Which A_RELEVANT_ATTR do not apply to the sub-type
  # 2110 to 2129 in use below
  A_TYPE_CREATE_DEFAULT_SUBTYPE = 2130      # Which sub-type should be offered by default?
  A_TYPE_CREATE_SHOW_SUBTYPE    = 2131      # Show this sub-type in the create menu? (0 = hide)
  A_ATTR_DESCRIPTIVE            = 2132      # Attributes which is necessary to fully describe the object as well as the title
  A_DISPLAY_ELEMENTS            = 2133      # Which Elements are to be displayed around objects of this type
  A_TYPE_LABELLING_ATTR         = 2134      # Which attributes are labelling attributes for this type (root only)
  A_TYPE_BASE_LABEL             = 2135      # Which labels should be always be applied to objects of this type
  A_TYPE_APPLICABLE_LABEL       = 2136      # Set of labels, one of which will always be applied if non-empty
  A_TYPE_LABEL_DEFAULT          = 2137      # Default applicable label
  A_TYPE_ANNOTATION             = 2138      # Annotation for type (API code, of interest to plugins only)

  # Attributes
  A_ATTR_QUALIFIER              = 2110
  A_ATTR_CONTROL_BY_TYPE        = 2112
  A_ATTR_CONTROL_RELAXED        = 2114
  # 2115 was A_ATTR_CATALOGUING_EXAMPLE
  A_ATTR_ALIAS_OF               = 2116      # For aliased attributes
  A_ATTR_UI_OPTIONS             = 2117      # Data type specific options
  A_ATTR_DATA_TYPE_OPTIONS      = 2118      # String, refines info about data type

  # Generic structural
  A_ORDERING                    = 2121      # Used to put lists in order
  A_INCLUDE_LABEL               = 2126
  A_EXCLUDE_LABEL               = 2127
  A_INCLUDE_TYPE                = 2128

  # ============================ 2130 -- 213039 used above in Types section ============================

  # Taxonomy
  A_TAXONOMY_RELATED_TERM       = 2160      # TODO: Can this be done with DC elements instead?

  # Navigation
  # A_NAVIGATION_ENTRY            = 2170

  # Labels
  A_LABEL_CATEGORY              = 2180      # for objects of O_TYPE_LABEL

  # User displayed fields (starting at 2500)
  A_DOCUMENT                    = 2500
  A_NOTES                       = 2501
  A_FILE                        = 2502

  # Displayed to user, default for plugins to define special objects and behaviours
  A_CONFIGURED_BEHAVIOUR        = 2555

  # =========================== LABELS ===========================

  O_LABEL_CATEGORY_SYSTEM       = KObjRef.new(BASE_APP_LABEL_DEFINITIONS + 1)

  O_LABEL_STRUCTURE             = KObjRef.new(BASE_APP_LABEL_DEFINITIONS + 11)
  O_LABEL_CONCEPT               = KObjRef.new(BASE_APP_LABEL_DEFINITIONS + 12)
  O_LABEL_ARCHIVED              = KObjRef.new(BASE_APP_LABEL_DEFINITIONS + 13)

  # Optional editable app category & labels
  O_LABEL_CATEGORY_SENSITIVITY  = KObjRef.new(BASE_APP_LABEL_DEFINITIONS + 41)
  O_LABEL_CATEGORY_UNNAMED      = KObjRef.new(BASE_APP_LABEL_DEFINITIONS + 42) # created by schema requirements if it needs it
  O_LABEL_COMMON                = KObjRef.new(BASE_APP_LABEL_DEFINITIONS + 51)
  O_LABEL_CONFIDENTIAL          = KObjRef.new(BASE_APP_LABEL_DEFINITIONS + 52)

  # =========================== TYPES ===========================

  O_TYPE_ATTR_ALIAS_DESC        = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 2)
  # KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 3) was O_TYPE_CHOICE_SET (defns for T_IDENTIFIER_CHOICE)

  # Type definitions
  O_TYPE_TYPE_BEHAVIOUR         = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 5)
  O_TYPE_TYPE_BEHAVIOUR_ROOT_ONLY = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 6)

  # A visible type is a type which the user can apply to an object.
  # These must have:
  #    A_TYPE of O_TYPE_APP_VISIBLE

  # KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 10) -- was O_TYPE_ROOT_VISIBLE

  # Types which are visible to the user have an A_TYPE attribute
  O_TYPE_APP_VISIBLE            = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 20)

  # Structural types
  O_TYPE_SUBSET_DESC            = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 31)
  O_TYPE_LABEL_CATEGORY         = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 32)
  O_TYPE_LABEL                  = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 33)

  # Type behaviours
  O_TYPE_BEHAVIOUR_CLASSIFICATION  = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 40)
  O_TYPE_BEHAVIOUR_PHYSICAL     = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 41)
  O_TYPE_BEHAVIOUR_HIERARCHICAL = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 42)
  O_TYPE_BEHAVIOUR_SHOW_HIERARCHY  = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 43)
  O_TYPE_BEHAVIOUR_FORCE_LABEL_CHOICE  = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 44)
  O_TYPE_BEHAVIOUR_SELF_LABELLING = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 45)
  O_TYPE_BEHAVIOUR_HIDE_FROM_BROWSE = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 46)
  # NOTE: When adding to this list, also update schema requirements

  # Class types
  # KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 80) was O_TYPE_PHYSICAL_RESOURCE
  # KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 81) was O_TYPE_ONLINE_RESOURCE

  # Physical type definitions
  O_TYPE_BOOK                   = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 100)
  O_TYPE_SERIAL                 = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 110)  # inc by 10 for plenty of space
  O_TYPE_EQUIPMENT              = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 120)
  O_TYPE_COMPUTER               = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 121)
  O_TYPE_LAPTOP                 = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 122)
  O_TYPE_PRINTER                = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 123)
  O_TYPE_PROJECTOR              = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 124)

  # Online type definitions
  O_TYPE_WEB_SITE               = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 200)
  O_TYPE_QUICK_LINK             = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 201)
  O_TYPE_INTRANET_PAGE          = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 210)
  # KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 211) was O_TYPE_FAQ

  # Entity definitions (people, organisations)
  O_TYPE_ORGANISATION           = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 300)
  O_TYPE_CLIENT                 = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 301)
  O_TYPE_SUPPLIER               = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 302)
  O_TYPE_ORG_CLIENT_PAST        = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 303)
  O_TYPE_ORG_CLIENT_PROSPECTIVE = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 304)
  O_TYPE_ORG_PARTNER            = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 305)
  O_TYPE_ORG_PRESS              = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 306)
  O_TYPE_ORG_PROFESSIONAL_ASSOCIATION = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 307)
  O_TYPE_ORG_COMPETITOR         = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 308)
  O_TYPE_ORG_THIS               = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 309)

  # Gap in numbering
  # KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 309) was O_TYPE_CONTACT_CATEGORY

  # Events, activities, conferences
  O_TYPE_EVENT                  = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 350)
  O_TYPE_EVENT_CONFERENCE       = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 351)
  O_TYPE_EVENT_NETWORKING       = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 352)
  O_TYPE_EVENT_SOCIAL           = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 353)
  O_TYPE_EVENT_TRAINING         = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 354)

  # People
  O_TYPE_PERSON                 = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 400)
  O_TYPE_STAFF                  = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 401)
  # KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 402) was O_TYPE_AUTHOR
  O_TYPE_PERSON_STAFF_PAST      = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 403)
  O_TYPE_PERSON_ASSOCIATE       = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 404)

  # Files etc
  O_TYPE_FILE                   = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 500)
  # KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 501) was O_TYPE_DOCUMENT
  O_TYPE_REPORT                 = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 502)
  O_TYPE_PRESENTATION           = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 503)
  O_TYPE_IMAGE                  = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 504)
  # KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 505) was O_TYPE_SPREADSHEET
  O_TYPE_FILE_ACCOUNTS          = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 506)
  O_TYPE_FILE_BROCHURE          = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 507)
  O_TYPE_FILE_CONTRACT          = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 508)
  O_TYPE_FILE_MINUTES           = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 509)
  O_TYPE_FILE_NEWSLETTER        = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 510)
  O_TYPE_FILE_PRESS_RELEASE     = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 511)
  O_TYPE_FILE_TEMPLATE          = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 512)
  O_TYPE_FILE_AUDIO             = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 513)
  O_TYPE_FILE_VIDEO             = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 514)

  # Tasks etc
  # Leave +550 for a root type?
  O_TYPE_PROJECT                = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 551)

  # Information objects
  O_TYPE_NEWS                   = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 600)

  # Sets
  O_TYPE_SET                    = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 700)

  # Taxonomies
#  O_TYPE_TAXONOMY               = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 800)
#  O_TYPE_TAXONOMY_ROOT          = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 801)
  O_TYPE_TAXONOMY_TERM          = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 802)

  # Navigation
#  O_TYPE_NAVIGATION             = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 810)

  # Fallback for when a type can't be determined
  O_TYPE_UNKNOWN                = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 999)

  # Contact management application objects (may not actually be in the store)
  O_TYPE_CONTACT_NOTE           = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 1000)
  O_TYPE_CONTACT_NOTE_MEETING   = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 1001)
  O_TYPE_CONTACT_NOTE_TELEPHONE = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 1002)
  O_TYPE_CONTACT_NOTE_EMAIL     = KObjRef.new(BASE_APP_TYPE_DEFINITIONS + 1003)

  # Well known objects

  # Flags
  # KObjRef.new(BASE_APP_WELL_KNOWN_OBJS + 100) was O_FLAG_PROVISIONAL
  # KObjRef.new(BASE_APP_WELL_KNOWN_OBJS + 101) was O_FLAG_BAD_CONVERSION

  # --------------------------------------------------------------
  # Where the new type offers are shown
  TYPEUIPOS_COMMON      = -1  # High priority for Tools page
  TYPEUIPOS_NORMAL      = 0   # Default, as nil.to_i == 0
  TYPEUIPOS_INFREQUENT  = 1   # Needs an extra click to reveal
  TYPEUIPOS_NEVER       = 2   # hides from UI

end

