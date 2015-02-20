
-- Status of the app
INSERT INTO app_globals(key,value_int,value_string) VALUES('status',0,NULL);            -- 0 means "in process of being set up"

-- Limitations on the application
INSERT INTO app_globals(key,value_int,value_string) VALUES('limit_users',0,NULL);       -- how many active users are allowed, 0 = no limit
-- INSERT INTO app_globals(key,value_int,value_string) VALUES('limit_init_objects',0,NULL); -- how many objects were created on init
INSERT INTO app_globals(key,value_int,value_string) VALUES('limit_objects',0,NULL);     -- how many non-structure objects, 0 = no limit
INSERT INTO app_globals(key,value_int,value_string) VALUES('limit_storage',0,NULL);     -- how much storage in MB, 0 = no limit

-- Billing info - just HTML which is output with a few values interpolated.
INSERT INTO app_globals(key,value_int,value_string) VALUES('billing_page_html',NULL,'');

-- The user presentable name for the product (used in title on each page)
INSERT INTO app_globals(key,value_int,value_string) VALUES('product_name',NULL,'Haplo');

-- The user presentable name for this application
-- INSERT INTO app_globals(key,value_int,value_string) VALUES('system_name',NULL,'Readable Name');
-- (set by lib/kappinit.rb)

-- The preferred hostname used for this application, used in emails and other public URLs
-- INSERT INTO app_globals(key,value_int,value_string) VALUES('url_hostname',NULL,'hostname');
-- (set by lib/kappinit.rb)

-- The preferred hostname used for this application, for SSL URLs (different from the non-SSL hostname)
-- INSERT INTO app_globals(key,value_int,value_string) VALUES('ssl_hostname',NULL,'hostname');
-- (set by lib/kappinit.rb)

-- The SSL policy for the application
-- Three chars, for Anonymous, Logged in, and User exposed URLs: c = clear, e = encrypted
INSERT INTO app_globals(key,value_int,value_string) VALUES('ssl_policy',NULL,'cee');

-- Content-Security-Policy setting - either a liternal policy or a built-in policy starting with $
INSERT INTO app_globals(key,value_int,value_string) VALUES('content_security_policy',NULL,'$SECURE');

-- A YAML encoded Array of Hashes listing the installed plugins
INSERT INTO app_globals(key,value_int,value_string) VALUES('installed_plugins',NULL,'');

-- A YAML encoded Hash of plugin name to database namespace
INSERT INTO app_globals(key,value_int,value_string) VALUES('plugin_db_namespaces',NULL,'');

-- Schema editing
INSERT INTO app_globals(key,value_int,value_string) VALUES('schema_api_codes_locked',1,NULL);

-- JavaScript configuration data (as O.application.config)
INSERT INTO app_globals(key,value_int,value_string) VALUES('javascript_config_data',NULL,'{}');

-- Auditing options (plugins can override)
-- Auditing of read-like actions is off by default
INSERT INTO app_globals(key,value_int,value_string) VALUES('audit_object_display',0,NULL);
INSERT INTO app_globals(key,value_int,value_string) VALUES('audit_search',0,NULL);
INSERT INTO app_globals(key,value_int,value_string) VALUES('audit_file_downloads',0,NULL);

-- File identifier key (prevents users giving themselves access to files if they know the digest)
-- INSERT INTO app_globals(key,value_int,value_string) VALUES('file_secret_key',NULL,?);
-- (set by lib/kappinit.rb)

-- The contact email of an administrator, for use when sending emails
-- INSERT INTO app_globals(key,value_int,value_string) VALUES('admin_email_address',NULL,'contact@example.com');
-- (set by lib/kappinit.rb)

-- HTML inserted into the page header, or bare text for automatic inclusion in a div
-- INSERT INTO app_globals(key,value_int,value_string) VALUES('appearance_header',NULL,'Combined Information System');
-- (set by lib/kappinit.rb)
-- CSS styles for header, appended to main app.css file
INSERT INTO app_globals(key,value_int,value_string) VALUES('appearance_css',NULL,'');
-- Optional HTML to replace the footer
-- INSERT INTO app_globals(key,value_int,value_string) VALUES('appearance_footer',NULL,'');

-- OTP override code
-- INSERT INTO app_globals(key,value_int,value_string) VALUES('otp_override',NULL,?);
-- (created on demand by otp_controller)

-- Token (OTP) admin contact details
-- INSERT INTO app_globals(key,value_int,value_string) VALUES('otp_admin_contact',NULL,?);
-- (created on demand by application_controller)

-- What's the maximum length for a slug when generating a URL for an object?
INSERT INTO app_globals(key,value_int,value_string) VALUES('max_slug_length',32,NULL);

-- Appearance
-- Colours set in app init from default global
-- INSERT INTO app_globals(key,value_int,value_string) VALUES('appearance_colours',NULL,'= KApplicationColours::DEFAULT_CUSTOM_COLOURS');
INSERT INTO app_globals(key,value_int,value_string) VALUES('appearance_update_serial',1,NULL);

-- Web font setting - what size of webfonts should be delivered? 0 = none, 4 = western chars only, 8 = full font
INSERT INTO app_globals(key,value_int,value_string) VALUES('appearance_webfont_size',4,NULL);

-- What Elements are shown on the home page? (empty by default, but filled in when plugins installed)
INSERT INTO app_globals(key,value_int,value_string) VALUES('home_page_elements',NULL,'');

-- Copyright statement
INSERT INTO app_globals(key,value_int,value_string) VALUES('copyright_statement',NULL,'<doc><p>The copyright of content in Haplo remains the property of the copyright holder. Content held in Haplo may not be sold, licensed, transferred, copied, reproduced in whole or in part without the prior written consent of the copyright holder.</p></doc>');

-- Serial number of the schema and taxonomies -- set to current time when updating schema or taxonomy roots
-- Updated by KObjectStoreApplicationDelegate (lib/kdelegate_app.rb)
INSERT INTO app_globals(key,value_int,value_string) VALUES('schema_version',1,NULL);
-- Serial number of the per-user schema info for the editor.
INSERT INTO app_globals(key,value_int,value_string) VALUES('schema_user_version',1,NULL);

-- Navigation list
-- INSERT INTO app_globals(key,value_int,value_string) VALUES('navigation',NULL,'(some YAML)');
-- Version number of navigation, for expiring URLs
INSERT INTO app_globals(key,value_int,value_string) VALUES('navigation_version',1,NULL);

-- Time zone list
-- Default is set in KDisplayConfig
-- INSERT INTO app_globals(key,value_int,value_string) VALUES('timezones',NULL,'GMT,Europe/London');

-- Search by fields
-- Default is not to have no entry for this app global. Created only defaults are overridden. Defaults set in KConstants
-- INSERT INTO app_globals(key,value_int,value_string) VALUES('search_by_fields',NULL,'211,213');

-- Names of features
INSERT INTO app_globals(key,value_int,value_string) VALUES('name_latest',NULL,'latest updates');
INSERT INTO app_globals(key,value_int,value_string) VALUES('name_latest_request',NULL,'latest updates topic');
INSERT INTO app_globals(key,value_int,value_string) VALUES('name_latest_requests',NULL,'latest updates topics');

-- Enable features/options (1 = true, 0 = false)
INSERT INTO app_globals(key,value_int,value_string) VALUES('enable_feature_doc_text_html_widgets',0,NULL);
-- Add options to list in Setup_ApplicationController::ENABLE_FEATURES to implement UI

-- External providers of functionality
INSERT INTO app_globals(key,value_int,value_string) VALUES('map_provider',NULL,'maps.google.co.uk');
