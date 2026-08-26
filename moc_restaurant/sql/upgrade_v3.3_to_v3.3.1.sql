ALTER TABLE `moc_restaurants`
    ADD COLUMN IF NOT EXISTS `interaction_method`
    VARCHAR(20) NOT NULL DEFAULT 'prompt'
    AFTER `blip_z`;

UPDATE `moc_restaurants`
SET `interaction_method`='prompt'
WHERE `interaction_method` IS NULL OR `interaction_method`='';
