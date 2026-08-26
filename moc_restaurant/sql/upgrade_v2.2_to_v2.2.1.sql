-- MOC Restaurant v2.2.0 -> v2.2.1
-- Complete Deliveries & Restocking

ALTER TABLE `moc_deliveries`
    ADD COLUMN IF NOT EXISTS `ready_at` TIMESTAMP NULL DEFAULT NULL AFTER `cost`,
    ADD COLUMN IF NOT EXISTS `delivered_at` TIMESTAMP NULL DEFAULT NULL AFTER `ready_at`;

CREATE INDEX IF NOT EXISTS `idx_moc_deliveries_status_ready`
    ON `moc_deliveries` (`restaurant_id`, `status`, `ready_at`);
