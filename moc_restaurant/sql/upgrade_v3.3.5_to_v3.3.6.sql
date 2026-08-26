-- MOC Restaurant v3.3.5 -> v3.3.6
-- Removes the retired per-restaurant interaction-mode setting.
-- The script now uses the standard [E] prompt system for restaurant interactions.

ALTER TABLE `moc_restaurants`
    DROP COLUMN IF EXISTS `interaction_method`;
