CREATE TABLE IF NOT EXISTS `moc_deliveries` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `restaurant_id` INT NOT NULL,
    `requested_by` VARCHAR(50) NULL,
    `status` VARCHAR(30) NOT NULL DEFAULT 'ordered',
    `items` LONGTEXT NOT NULL,
    `cost` INT NOT NULL DEFAULT 0,
    `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
