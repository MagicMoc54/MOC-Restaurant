CREATE TABLE IF NOT EXISTS `moc_order_packages` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `order_id` INT NOT NULL,
    `restaurant_id` INT NOT NULL,
    `package_type` VARCHAR(20) NOT NULL,
    `sealed` TINYINT(1) NOT NULL DEFAULT 0,
    `items` LONGTEXT NULL,
    `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_moc_package_order` (`order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
