
--------------------------------------------------------------------------------------
-- Object store
--------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------
--  IMPORTANT NOTE
--  If index tables are added, add to KObjectStore::ALL_INDEX_TABLES and test cleanup.
--------------------------------------------------------------------------------------


CREATE TABLE os_objects (
    id SERIAL PRIMARY KEY,
    version INT NOT NULL,
    labels int[] NOT NULL,
    -- TODO: os_objects.creation_time isn't strictly the correct name for this field; it's only suitable for sorting in date order.
    creation_time TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by INT NOT NULL,    -- who created this object as external user ID
    updated_by INT NOT NULL,    -- last update of this object as external user ID
    type_object_id INT NOT NULL,-- os_objects(id) of first_attr(A_TYPE) if is a KObjRef
    sortas_title TEXT NOT NULL, -- first A_TITLE entry, default language, normalised to lowercase, no-accents
    object BYTEA NOT NULL       -- Object in Ruby serialised format
);
CREATE INDEX idx_os_objects_labels ON os_objects using gin (labels gin__int_ops);
CREATE INDEX idx_os_objects_sortas_title ON os_objects(sortas_title);
CREATE INDEX idx_os_objects_creation ON os_objects(creation_time);
CREATE INDEX idx_os_objects_update ON os_objects(updated_at);

-- Set the first object value to more than the reserved range
SELECT setval('os_objects_id_seq', 524288+16); -- Sync with KConstants::MAX_RESERVED_OBJID


-- Old versions are kept in a separate table
CREATE TABLE os_objects_old (
    id INT NOT NULL,          -- os_objects(id), not unique
    version INT NOT NULL,
    labels int[] NOT NULL,
    creation_time TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    created_by INT NOT NULL,    -- copy from os_objects
    updated_by INT NOT NULL,    -- copy from os_objects
    retired_by INT NOT NULL,    -- who retired this object as external user ID == os_objects.updated_by for latest version if not deleted
    type_object_id INT NOT NULL,-- os_objects(id) of first_attr(A_TYPE) if is a KObjRef
    sortas_title TEXT NOT NULL, -- first A_TITLE entry, default language, normalised to lowercase, no-accents
    object BYTEA NOT NULL       -- Object in Ruby serialised format
);
CREATE UNIQUE INDEX idx_os_objects_old_idver ON os_objects_old(id,version); -- id on itself is not unique


-- Index tables
CREATE TABLE os_index_int (
    id INT NOT NULL,
    attr_desc INT NOT NULL,     -- Attribute Descriptor, as int (can't use 'desc' as name)
    qualifier INT NOT NULL,     -- Attribute Qualifier, as int
    restrictions INT[],         -- Restriction labels, or NULL for none
    value INT NOT NULL
);
CREATE INDEX os_index_int_idx ON os_index_int(id,attr_desc,qualifier);
CREATE INDEX os_index_int_v_idx ON os_index_int(value);

CREATE TABLE os_index_link (
    id INT NOT NULL,
    attr_desc INT NOT NULL,     -- Attribute Descriptor, as int (can't use 'desc' as name)
    qualifier INT NOT NULL,     -- Attribute Qualifier, as int
    restrictions INT[],         -- Restriction labels, or NULL for none
    value int[] NOT NULL,
    object_id INT NOT NULL      -- os_objects(id) of the object linked to
);
CREATE INDEX os_index_link_idx ON os_index_link(id,attr_desc,qualifier);
CREATE INDEX os_index_link_o_idx ON os_index_link(object_id);
CREATE INDEX os_index_link_v_idx ON os_index_link using gin (value gin__int_ops);
CREATE INDEX os_index_link_i_idx ON os_index_link(object_id,attr_desc,qualifier);

CREATE TABLE os_index_identifier (
    id INT NOT NULL,
    attr_desc INT NOT NULL,     -- Attribute Descriptor, as int (can't use 'desc' as name)
    qualifier INT NOT NULL,     -- Attribute Qualifier, as int
    restrictions INT[],         -- Restriction labels, or NULL for none
    identifier_type INT NOT NULL, -- k_typecode
    value TEXT NOT NULL         -- Text of identifier value
);
CREATE INDEX os_index_identifier_idx ON os_index_identifier(id,attr_desc,qualifier);
CREATE INDEX os_index_identifier_v_idx ON os_index_identifier(identifier_type,value);

CREATE TABLE os_index_datetime (
    id INT NOT NULL,
    attr_desc INT NOT NULL,     -- Attribute Descriptor, as int (can't use 'desc' as name)
    qualifier INT NOT NULL,     -- Attribute Qualifier, as int
    restrictions INT[],         -- Restriction labels, or NULL for none
    value TIMESTAMP NOT NULL,   -- Beginning of range (inclusive)
    value2 TIMESTAMP NOT NULL   -- End of range (exclusive)
);
CREATE INDEX os_index_datetime_idx ON os_index_datetime(id,attr_desc,qualifier);
CREATE INDEX os_index_datetime_v_idx ON os_index_datetime(value, value2);
CREATE INDEX os_index_datetime_v2_idx ON os_index_datetime(value2);


-- Initial versions of auto-generated functions

CREATE OR REPLACE FUNCTION os_type_relevancy(type_obj_id INTEGER) RETURNS FLOAT4 AS $$
BEGIN
    RETURN 1.0;
END;
$$ LANGUAGE plpgsql;




