-- Tambah kolom untuk trigger ke tabel mission_goals
ALTER TABLE mission_goals 
ADD COLUMN next_goal_trigger VARCHAR(20) DEFAULT 'auto',
ADD COLUMN wait_time INT DEFAULT 5,
ADD COLUMN sensor_type VARCHAR(50) DEFAULT '',
ADD COLUMN sensor_condition TEXT DEFAULT '',
ADD COLUMN timeout INT DEFAULT 60,
ADD COLUMN retry_count INT DEFAULT 0,
ADD COLUMN on_failure VARCHAR(20) DEFAULT 'skip';