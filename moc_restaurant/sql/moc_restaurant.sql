CREATE TABLE IF NOT EXISTS `moc_restaurants` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(100) NOT NULL,
    `job` VARCHAR(50) NULL,
    `owner` VARCHAR(50) NULL,
    `type` VARCHAR(50) NOT NULL,
    `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `moc_locations` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `restaurant_id` INT NOT NULL,
    `location_type` VARCHAR(50) NOT NULL,
    `x` DOUBLE NOT NULL,
    `y` DOUBLE NOT NULL,
    `z` DOUBLE NOT NULL,
    `heading` DOUBLE NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_moc_locations_restaurant` (`restaurant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `moc_menu` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `restaurant_id` INT NOT NULL,
    `item` VARCHAR(100) NOT NULL,
    `label` VARCHAR(100) NOT NULL,
    `price` INT NOT NULL DEFAULT 0,
    `category` VARCHAR(50) NOT NULL DEFAULT 'Menu',
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`id`),
    KEY `idx_moc_menu_restaurant` (`restaurant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `moc_orders` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `restaurant_id` INT NOT NULL,
    `customer` VARCHAR(50) NULL,
    `employee` VARCHAR(50) NULL,
    `status` VARCHAR(50) NOT NULL DEFAULT 'pending',
    `order_type` VARCHAR(30) NOT NULL DEFAULT 'counter',
    `payment_type` VARCHAR(20) NULL,
    `subtotal` INT NOT NULL DEFAULT 0,
    `tax` INT NOT NULL DEFAULT 0,
    `total` INT NOT NULL DEFAULT 0,
    `items` LONGTEXT NULL,
    `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_moc_orders_restaurant` (`restaurant_id`),
    KEY `idx_moc_orders_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `moc_storage` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `restaurant_id` INT NOT NULL,
    `item` VARCHAR(100) NOT NULL,
    `amount` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_moc_storage_restaurant` (`restaurant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
