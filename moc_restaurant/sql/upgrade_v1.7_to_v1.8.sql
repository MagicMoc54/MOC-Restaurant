ALTER TABLE `moc_orders`
    ADD COLUMN IF NOT EXISTS `vehicle_plate` VARCHAR(20) NULL;
