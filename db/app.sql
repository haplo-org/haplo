

-- Tables defined in this file are defined in the applications private schema.

--------------------------------------------------------------------------------------
-- Application global data (static configuration and dynamic information)
--------------------------------------------------------------------------------------

CREATE TABLE app_globals (
    key TEXT NOT NULL,
    value_int INT,
    value_string TEXT
);
CREATE INDEX idx_app_globals ON app_globals(key);


--------------------------------------------------------------------------------------
-- Application static files (intended mainly for images in page headers)
--------------------------------------------------------------------------------------

CREATE TABLE app_static_files (
    id SERIAL PRIMARY KEY,
    filename TEXT NOT NULL,
    mime_type TEXT NOT NULL,
    data BYTEA NOT NULL
);


--------------------------------------------------------------------------------------
-- Users and groups (both defined in users table)
--------------------------------------------------------------------------------------

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    kind SMALLINT NOT NULL DEFAULT(0),  -- 0 = user, 1 = group
    obj_id INT,                         -- optional, users only, object representing this user
    code TEXT,                          -- optional, groups only, for JS API
    name TEXT NOT NULL,                 -- "#{name_first} #{name_last}" if user (enforced in model), group name if group
    name_first TEXT,                    -- NULL for groups
    name_last TEXT,                     -- NULL for groups
    email TEXT,                         -- optional for groups
    password TEXT,                      -- NULL for groups
    recovery_token TEXT,                -- For recreating passwords
    otp_identifier TEXT                 -- Identifier of the user's OTP token, or NULL if the user doesn't have one
);
CREATE INDEX idx_users_kind ON users(kind);
CREATE INDEX idx_users_name ON users(lower(name));      -- lower index
CREATE INDEX idx_users_email ON users(lower(email));    -- lower index
CREATE INDEX idx_users_obj_id ON users(obj_id);

CREATE TABLE user_memberships (
    user_id INT NOT NULL REFERENCES users(id),
    member_of INT NOT NULL REFERENCES users(id),
    is_active BOOLEAN NOT NULL DEFAULT(TRUE)
);
CREATE INDEX idx_user_memberships_uid ON user_memberships(user_id);
CREATE INDEX idx_user_memberships_mo ON user_memberships(member_of);

-- Initial special groups and users (sync ids with constants in User object)
-- Copy changes into test/fixtures/users.csv
INSERT INTO users (id,kind,name,name_first,name_last) VALUES (0,3,'SYSTEM','SYSTEM',''); -- user representing full priv system code
INSERT INTO users (id,kind,name) VALUES (2,0,'ANONYMOUS');
INSERT INTO users (id,kind,name,name_first,name_last) VALUES (3,3,'SUPPORT','SUPPORT','');  -- support login user
INSERT INTO users (id,kind,name,code) VALUES (4,1,'Everyone','std:group:everyone');
INSERT INTO users (id,kind,name,code) VALUES (16,1,'Administrators','std:group:administrators');
SELECT setval('users_id_seq', 128);   -- first user created by app has ID > 128


--------------------------------------------------------------------------------------
-- Permissions and Policies
--------------------------------------------------------------------------------------

CREATE TABLE permission_rules (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id),
    label_id INT NOT NULL,
    statement SMALLINT NOT NULL,    -- CAN, CANNOT, RESET
    permissions INT NOT NULL        -- bitmask
);
CREATE UNIQUE INDEX idx_permission_rules_uid_lid_stmt ON permission_rules(user_id,label_id, statement); -- add constraint & user_id lookup

CREATE TABLE policies (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id), -- refers to a group or a user
  perms_allow INT NOT NULL,
  perms_deny INT NOT NULL
);
CREATE UNIQUE INDEX idx_policies_user_id ON policies(user_id);

--------------------------------------------------------------------------------------
-- User data. See user_data.rb -- some values can be inherited from parent groups
--------------------------------------------------------------------------------------

CREATE TABLE user_datas (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE, -- CASCADE allows test fixtures to work, duplicates rails stuff
    data_name SMALLINT NOT NULL,   -- integer 'names' allocated in user_data.rb
    data_value TEXT                 -- value converted to string
);
CREATE UNIQUE INDEX idx_user_data_udt ON user_datas(user_id,data_name); -- add constraint
-- not intended for queries over values


--------------------------------------------------------------------------------------
-- API keys, used for authenticating API access
--------------------------------------------------------------------------------------

CREATE TABLE api_keys (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id),  -- which user this entity will use, must be KIND_USER
    a TEXT NOT NULL,                            -- first half of the API key, stored in plain text
    b TEXT NOT NULL,                            -- second half of the API key, stored as bcrypt
    path TEXT NOT NULL,                         -- only allowed to access paths with this prefix
    name TEXT NOT NULL                          -- user readable name which describes this key
);
CREATE UNIQUE INDEX idx_api_keys_key ON api_keys(a);


--------------------------------------------------------------------------------------
-- Audit trail
--------------------------------------------------------------------------------------

CREATE TABLE audit_entries (
    id SERIAL PRIMARY KEY,
    created_at TIMESTAMP NOT NULL,
    remote_addr TEXT,                           -- remote address, if applicable
    user_id INT NOT NULL,                       -- no referencial integrity so audit trail is independent.
    auth_user_id INT NOT NULL,                  -- user which was authenticated (not changed by impersonation)
    api_key_id INT,                             -- which API key was used to authenticate (which might have been deleted, but you can trace back in trail)
    kind TEXT NOT NULL,
    labels int[] NOT NULL,                      -- labels for visibility
    obj_id INT,                                 -- only if refers to an object
    entity_id INT,                              -- if it refers to some other entity (work unit, file, etc)
    version INT,                                -- version number of object / file if applicable
    displayable BOOLEAN NOT NULL,               -- displayed to use in timeline?
    data TEXT                                   -- JSON encoded details
);
-- TODO: Review use of indicies for audit_entries
CREATE INDEX idx_audit_en_date ON audit_entries(created_at);
CREATE INDEX idx_audit_en_kind ON audit_entries(kind,entity_id);        -- entity_id should only be used when filtering on kind too
CREATE INDEX idx_audit_en_obj_id ON audit_entries(obj_id);
CREATE INDEX idx_audit_en_user1 ON audit_entries(user_id);
CREATE INDEX idx_audit_en_user2 ON audit_entries(auth_user_id);
CREATE INDEX idx_audit_en_recent ON audit_entries(displayable,id); -- for recent listing
-- PERM TODO: Benchmark GIN vs GiST indicies, and on GiST, gist__intbig_ops vs gist__intbig_ops
CREATE INDEX idx_audit_en_labels ON audit_entries using gin (labels gin__int_ops);


--------------------------------------------------------------------------------------
-- Email templates
--------------------------------------------------------------------------------------

CREATE TABLE email_templates (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    purpose TEXT NOT NULL DEFAULT('Generic'),
    from_email_address TEXT NOT NULL,
    from_name TEXT NOT NULL,
    extra_css TEXT,
    branding_plain TEXT,
    branding_html TEXT,
    header TEXT,
    footer TEXT,
    in_menu BOOLEAN NOT NULL DEFAULT(TRUE)
);
SELECT setval('email_templates_id_seq', 128);   -- first template created by app has ID > 128


--------------------------------------------------------------------------------------
-- Latest updates service
--------------------------------------------------------------------------------------

CREATE TABLE latest_requests (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id),   -- user/group for this item
    inclusion SMALLINT NOT NULL,        -- include, exclude/default off, force include
    obj_id INT NOT NULL
);
CREATE INDEX idx_latest_user_id ON latest_requests(user_id);


--------------------------------------------------------------------------------------
-- File store
--------------------------------------------------------------------------------------

CREATE TABLE stored_files (
    id SERIAL PRIMARY KEY,
    created_at TIMESTAMP NOT NULL,
    digest TEXT NOT NULL,           -- using digest named in StoredFile::FILE_DIGEST_ALGORITHM
    size BIGINT NOT NULL,           -- 64 bits of file size
        -- NOTE: size used to calculate disc space usage
    upload_filename TEXT NOT NULL,  -- filename given when uploaded, probably not the one offered on downloads
    mime_type TEXT NOT NULL,
    dimensions_w INT,
    dimensions_h INT,
    dimensions_units TEXT,          -- dimensions, may be NULL if not calculated or not available
    dimensions_pages INT,           -- number of pages, if known
    thumbnail_w SMALLINT,
    thumbnail_h SMALLINT,           -- dimensions of thumbnail image, NULL if not calculated or not available
    thumbnail_format SMALLINT,      -- format of thumbnail, see StoredFile::THUMBNAIL_FORMAT_*
    render_text_chars INT           -- number of characters of plain text available for rendering excerpts (not complete enough for indexing etc)
);
CREATE UNIQUE INDEX idx_stored_files_lookup ON stored_files(digest,size);


--------------------------------------------------------------------------------------
-- Transformed file cache
--------------------------------------------------------------------------------------

CREATE TABLE file_cache_entries (
    id SERIAL PRIMARY KEY,
    created_at TIMESTAMP NOT NULL,
    last_access TIMESTAMP NOT NULL,
    access_count INT NOT NULL DEFAULT(1),
    stored_file_id INT NOT NULL REFERENCES stored_files(id),
    output_mime_type TEXT NOT NULL,     -- '' for no transform
    output_options TEXT NOT NULL        -- '' for no options
);
CREATE INDEX idx_file_cache_entries_lookup ON file_cache_entries(stored_file_id,output_mime_type,output_options);


--------------------------------------------------------------------------------------
-- Workflow system
--------------------------------------------------------------------------------------

CREATE TABLE work_units (
    id SERIAL PRIMARY KEY,
    work_type TEXT NOT NULL,                          -- What kind of work unit this is
    -- The various dates for this unit of work
    created_at TIMESTAMP NOT NULL,
    opened_at TIMESTAMP NOT NULL,                     -- may be in future
    deadline TIMESTAMP,
    closed_at TIMESTAMP,                              -- time of completion (or have this NULL to mean open?)
    -- Users
    created_by_id INT NOT NULL REFERENCES users(id),     -- Users only
    actionable_by_id INT NOT NULL REFERENCES users(id),  -- User or Group
    closed_by_id INT REFERENCES users(id),               -- Users only
    -- Additional data
    obj_id INT,   -- if applicable to an object
    data TEXT     -- JSON encoded data
);
CREATE INDEX idx_work_units_objref ON work_units(obj_id);
CREATE INDEX idx_work_units_aid_times ON work_units(actionable_by_id,opened_at,closed_at);


--------------------------------------------------------------------------------------
-- Keychain for stored credentials
--------------------------------------------------------------------------------------

CREATE TABLE keychain_credentials (
    id SERIAL PRIMARY KEY,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    name TEXT NOT NULL,
    kind TEXT NOT NULL,
    instance_kind TEXT NOT NULL,
    account_json TEXT NOT NULL, -- server names, account IDs, etc
    secret_json TEXT NOT NULL   -- passwords, tokens, etc
    -- TODO: Some sort of encryption of the secret material in the keychain?
);
-- No indicies because there's unlikely to be enough entries for them to be used.
