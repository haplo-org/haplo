CREATE OR REPLACE FUNCTION khq_copy_objectstore_contents(source_schema text, dest_schema text) RETURNS void AS
$$
DECLARE
  object text;
BEGIN

  FOR object IN
    SELECT table_name::text FROM information_schema.tables WHERE table_schema = source_schema AND table_name LIKE 'os_%' ORDER BY table_name
  LOOP
    EXECUTE 'INSERT INTO ' || dest_schema || '.' || object || ' (SELECT * FROM ' || source_schema || '.' || object || ')';
  END LOOP;

  FOR object IN
    SELECT sequence_name::text FROM information_schema.sequences WHERE sequence_schema = source_schema AND sequence_name LIKE 'os_%' ORDER BY sequence_name
  LOOP
    EXECUTE E'SELECT setval(\'' || dest_schema || '.' || object || E'\', nextval(\'' || source_schema || '.' || object || E'\'), false)';
  END LOOP;

  FOR object IN
    SELECT prosrc FROM pg_catalog.pg_proc WHERE proname LIKE 'os_type_relevancy' AND pronamespace=(SELECT oid FROM pg_catalog.pg_namespace WHERE nspname=source_schema)
  LOOP
    EXECUTE 'CREATE OR REPLACE FUNCTION ' || dest_schema || E'.os_type_relevancy(type_obj_id INTEGER) RETURNS FLOAT4 AS \$\$ ' || object || E' \$\$ LANGUAGE plpgsql';
  END LOOP;

END;
$$ LANGUAGE plpgsql VOLATILE;



CREATE OR REPLACE FUNCTION khq_clear_os_tables(dest_schema text) RETURNS void AS
$$
DECLARE
  object text;
BEGIN

  FOR object IN
    SELECT table_name::text FROM information_schema.tables WHERE table_schema = dest_schema AND table_name LIKE 'os_%' ORDER BY table_name
  LOOP
    EXECUTE 'TRUNCATE ' || dest_schema || '.' || object || ' RESTART IDENTITY CASCADE';
  END LOOP;

END;
$$ LANGUAGE plpgsql VOLATILE;
