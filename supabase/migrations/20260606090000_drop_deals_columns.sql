-- Drop the legacy free-text deal columns from `restaurants`.
--
-- Promotions now live in the normalized `restaurant_offers` table (see
-- 20260606040000_restaurant_offers.sql + 20260606070000_offer_category.sql),
-- which is the single source of truth read by both the iOS app and the web/PWA.
--
-- Sequencing: deploy the web build and ship the iOS build that stop reading and
-- writing these columns BEFORE running this migration. After both clients are
-- updated, dropping the columns is safe — nothing references them.
ALTER TABLE restaurants
  DROP COLUMN IF EXISTS deals,
  DROP COLUMN IF EXISTS deals_zh_hans,
  DROP COLUMN IF EXISTS deals_zh_hant;
