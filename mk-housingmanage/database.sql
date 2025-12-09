-- mk-housingmanage Database Schema
-- Run this SQL to set up the required database tables

CREATE TABLE IF NOT EXISTS `player_houses` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `owner` VARCHAR(60) NOT NULL,
    `address` VARCHAR(100) NOT NULL,
    `area` VARCHAR(100) NOT NULL,
    `price` INT(11) NOT NULL DEFAULT 0,
    `garage_spots` INT(11) NOT NULL DEFAULT 1,
    `max_residents` INT(11) NOT NULL DEFAULT 2,
    `is_locked` TINYINT(1) NOT NULL DEFAULT 1,
    `paid_until` DATETIME NULL,
    `workshop_level` INT(11) NOT NULL DEFAULT 0,
    `image_url` VARCHAR(255) NULL,
    `coords_x` FLOAT NULL,
    `coords_y` FLOAT NULL,
    `coords_z` FLOAT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_owner` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `house_residents` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `house_id` INT(11) NOT NULL,
    `resident_id` VARCHAR(60) NOT NULL,
    `name` VARCHAR(50) NOT NULL,
    `surname` VARCHAR(50) NOT NULL,
    `moved_in` VARCHAR(20) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_house_id` (`house_id`),
    INDEX `idx_resident_id` (`resident_id`),
    CONSTRAINT `fk_house_residents_house` FOREIGN KEY (`house_id`) REFERENCES `player_houses` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Sample data for testing
INSERT INTO `player_houses` (`owner`, `address`, `area`, `price`, `garage_spots`, `max_residents`, `is_locked`, `paid_until`, `workshop_level`) VALUES
('steam:110000123456789', 'Route 68', 'Grand Senora Desert', 120000, 2, 2, 1, DATE_ADD(NOW(), INTERVAL 30 DAY), 0),
('steam:110000123456789', 'Vinewood Hills', 'Los Santos', 450000, 4, 4, 0, DATE_ADD(NOW(), INTERVAL 45 DAY), 1);
