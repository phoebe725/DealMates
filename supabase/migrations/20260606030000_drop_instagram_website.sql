-- instagram_handle and website_url were never populated or read by either
-- client. Drop them to keep the schema honest.
ALTER TABLE restaurants DROP COLUMN IF EXISTS instagram_handle;
ALTER TABLE restaurants DROP COLUMN IF EXISTS website_url;
