-- MOC Restaurant v1.5.4 -> v1.5.5
ALTER TABLE `moc_locations`
    ADD COLUMN IF NOT EXISTS `interaction_radius` DECIMAL(5,2) NOT NULL DEFAULT 0.65 AFTER `heading`;

-- Existing locations get the new small default automatically.
UPDATE `moc_locations`
SET `interaction_radius` = 0.65
WHERE `interaction_radius` IS NULL OR `interaction_radius` <= 0;
