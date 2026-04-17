-- Cleanup script for old Government Map optional tables.
-- Safe to run multiple times.

USE mezaan_db;

DROP TABLE IF EXISTS user_recent_government_places;
DROP TABLE IF EXISTS user_favorite_government_places;
