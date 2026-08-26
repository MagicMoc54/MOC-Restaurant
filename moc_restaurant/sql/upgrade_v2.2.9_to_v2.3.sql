CREATE TABLE IF NOT EXISTS `moc_loyalty` (
    `restaurant_id` INT NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `points` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`restaurant_id`,`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
