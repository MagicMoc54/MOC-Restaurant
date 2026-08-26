CREATE TABLE IF NOT EXISTS `moc_employees` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `restaurant_id` INT NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `role` VARCHAR(50) NOT NULL DEFAULT 'employee',
    `clocked_in` TINYINT(1) NOT NULL DEFAULT 0,
    `minutes_worked` INT NOT NULL DEFAULT 0,
    `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_moc_employee` (`restaurant_id`,`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `moc_job_ranks` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `restaurant_id` INT NOT NULL,
    `grade` INT NOT NULL,
    `name` VARCHAR(50) NOT NULL,
    `label` VARCHAR(100) NOT NULL,
    `pay` INT NOT NULL DEFAULT 0,
    `isboss` TINYINT(1) NOT NULL DEFAULT 0,
    `permissions` LONGTEXT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_moc_rank` (`restaurant_id`,`grade`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `moc_payroll` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `restaurant_id` INT NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `grade` INT NOT NULL,
    `amount` INT NOT NULL DEFAULT 0,
    `status` VARCHAR(30) NOT NULL DEFAULT 'paid',
    `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `moc_sales` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `restaurant_id` INT NOT NULL,
    `order_id` INT NULL,
    `gross` INT NOT NULL DEFAULT 0,
    `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
