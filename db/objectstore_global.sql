
--------------------------------------------------------------------------------------
-- Object store (global tables)
--------------------------------------------------------------------------------------

-- These tables live in the public schema, and are shared between all object stores.

-- Which objects are waiting to have their text indexed?
-- Not indexed as the common case is for not many objects to be queued.
-- See comments in kobjectstore_textidx.rb
CREATE TABLE os_dirty_text (
    id SERIAL PRIMARY KEY,
    app_id INT NOT NULL,        -- which store this referes to
    osobj_id INT NOT NULL       -- os_objects(id) in the app
);

-- Which stores need reindexing?
CREATE TABLE os_store_reindex (
    id SERIAL PRIMARY KEY,
    app_id INT NOT NULL,        -- which store this referes to
    filter_by_attr TEXT NULL NULL, -- if not empty string, a comma separated list of attributes. Only reindex objs with these attributes
    requested_at TIMESTAMP NOT NULL DEFAULT(NOW())  -- when the reindex was requested
);
