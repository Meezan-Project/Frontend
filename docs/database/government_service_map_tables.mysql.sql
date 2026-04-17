-- MySQL 8+ schema for Government Service Map in mezaan_db
-- Run in MySQL Workbench after: USE mezaan_db;

CREATE TABLE IF NOT EXISTS government_places (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  external_id VARCHAR(64) NOT NULL,
  source_type VARCHAR(16) NOT NULL,
  source_numeric_id VARCHAR(32) NOT NULL,
  name VARCHAR(255) NOT NULL,
  category VARCHAR(255) NOT NULL,
  type_key VARCHAR(32) NOT NULL,
  lat DECIMAL(10,7) NOT NULL,
  lng DECIMAL(10,7) NOT NULL,
  address TEXT NULL,
  working_hours TEXT NULL,
  is_user_jurisdiction TINYINT(1) NOT NULL DEFAULT 0,
  raw_tags_json JSON NULL,
  fetched_at_utc DATETIME NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_government_places_external_id (external_id),
  KEY idx_government_places_type_key (type_key),
  KEY idx_government_places_geo (lat, lng)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
