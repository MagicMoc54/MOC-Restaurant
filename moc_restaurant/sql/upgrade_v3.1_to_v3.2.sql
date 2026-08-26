ALTER TABLE `moc_restaurants`
    ADD COLUMN IF NOT EXISTS `restaurant_key` VARCHAR(64) NULL AFTER `job`;

CREATE TABLE IF NOT EXISTS `moc_restaurant_menu_items` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `restaurant_id` INT NOT NULL,
    `item_name` VARCHAR(100) NOT NULL,
    `label` VARCHAR(100) NOT NULL,
    `category` VARCHAR(50) NOT NULL DEFAULT 'Food',
    `price` INT NOT NULL DEFAULT 0,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `sort_order` INT NOT NULL DEFAULT 0,
    `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_moc_menu_restaurant_item` (`restaurant_id`,`item_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `moc_restaurant_recipes` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `restaurant_id` INT NOT NULL,
    `output_item` VARCHAR(100) NOT NULL,
    `label` VARCHAR(100) NOT NULL,
    `station_type` VARCHAR(50) NOT NULL,
    `output_amount` INT NOT NULL DEFAULT 1,
    `ingredients` LONGTEXT NOT NULL,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_moc_recipe_restaurant_output` (`restaurant_id`,`output_item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
