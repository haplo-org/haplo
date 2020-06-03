ALTER TABLE os_store_reindex ALTER COLUMN filter_by_attr SET NOT NULL;
ALTER TABLE os_store_reindex ADD COLUMN progress INT NOT NULL DEFAULT(0); 

