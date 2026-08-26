-- MOC Restaurant v3.2.0 -> v3.2.1
-- Clean Kitchen Production build

-- Ingredient Supplier has been retired in favor of Deliveries & Restocking.
-- Remove old placed supplier locations so they do not remain as dead stations.
DELETE FROM `moc_locations`
WHERE `location_type` = 'ingredient_supplier';

-- No new tables are required.
SELECT 1;
