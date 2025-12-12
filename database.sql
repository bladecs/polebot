-- Buat database
CREATE DATABASE IF NOT EXISTS polebot;
USE polebot;

-- Tabel: categories (buat dulu karena direferensi oleh missions)
CREATE TABLE categories (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    icon VARCHAR(50) DEFAULT 'fas fa-folder',
    color VARCHAR(20) DEFAULT '#3b82f6',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_categories_name (name)
);

-- Insert default category
INSERT INTO categories (id, name, description) VALUES (1, 'Default', 'Default mission category');

-- Tabel: maps
CREATE TABLE maps (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL UNIQUE,
    resolution DECIMAL(10, 5) DEFAULT 0.05,
    origin_x DECIMAL(10, 5) DEFAULT 0.0,
    origin_y DECIMAL(10, 5) DEFAULT 0.0,
    width INT DEFAULT 0,
    height INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_maps_name (name)
);

-- Tabel: goal_sets
CREATE TABLE goal_sets (
    id INT PRIMARY KEY AUTO_INCREMENT,
    map_id INT NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    total_goals INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (map_id) REFERENCES maps(id) ON DELETE CASCADE,
    UNIQUE KEY unique_set_name (name),
    INDEX idx_goal_sets_map (map_id),
    INDEX idx_goal_sets_name (name)
);

-- Tabel: goals
CREATE TABLE goals (
    id INT PRIMARY KEY AUTO_INCREMENT,
    goal_set_id INT NOT NULL,
    sequence_number INT NOT NULL,
    position_x DECIMAL(10, 5) NOT NULL,
    position_y DECIMAL(10, 5) NOT NULL,
    orientation_z DECIMAL(10, 5) DEFAULT 0.0,
    orientation_w DECIMAL(10, 5) DEFAULT 1.0,
    tolerance_xy DECIMAL(10, 5) DEFAULT 0.3,
    tolerance_yaw DECIMAL(10, 5) DEFAULT 0.5,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (goal_set_id) REFERENCES goal_sets(id) ON DELETE CASCADE,
    UNIQUE KEY unique_goal_sequence (goal_set_id, sequence_number),
    INDEX idx_goals_set (goal_set_id),
    INDEX idx_goals_sequence (sequence_number)
);

-- Tabel: missions (buat tabel ini sebelum mission_goals)
CREATE TABLE missions (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category_id INT DEFAULT 1,
    last_executed TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET DEFAULT,
    INDEX idx_missions_name (name),
    INDEX idx_missions_category (category_id)
);

-- Mission goals junction table dengan trigger support - TELAH DIPERBAIKI
CREATE TABLE mission_goals (
    id INT PRIMARY KEY AUTO_INCREMENT,
    mission_id INT NOT NULL,
    goal_id INT NOT NULL,
    sequence_number INT NOT NULL,
    
    -- Trigger configuration fields
    next_goal_trigger VARCHAR(20) DEFAULT 'auto',
    wait_time INT DEFAULT 5,
    sensor_type VARCHAR(50) DEFAULT '',
    sensor_condition TEXT, -- PERBAIKAN: Dihapus DEFAULT value untuk TEXT
    timeout INT DEFAULT 60,
    retry_count INT DEFAULT 0,
    on_failure VARCHAR(20) DEFAULT 'skip',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (mission_id) REFERENCES missions(id) ON DELETE CASCADE,
    FOREIGN KEY (goal_id) REFERENCES goals(id) ON DELETE CASCADE,
    UNIQUE KEY unique_mission_goal (mission_id, goal_id),
    INDEX idx_mission_goals_mission (mission_id),
    INDEX idx_mission_goals_goal (goal_id),
    INDEX idx_mission_goals_sequence (sequence_number),
    INDEX idx_mission_goals_trigger (next_goal_trigger)
);

-- View: goal_sets_summary
CREATE VIEW goal_sets_summary AS
SELECT 
    gs.id,
    gs.name,
    gs.description,
    m.name as map_name,
    gs.total_goals,
    COUNT(g.id) as saved_goals,
    gs.created_at
FROM goal_sets gs
JOIN maps m ON gs.map_id = m.id
LEFT JOIN goals g ON gs.id = g.goal_set_id
GROUP BY gs.id, gs.name, gs.description, m.name, gs.total_goals, gs.created_at;

-- View: missions_with_triggers_summary
CREATE VIEW missions_with_triggers_summary AS
SELECT 
    m.id,
    m.name,
    m.description,
    m.category_id,
    c.name as category_name,
    c.icon as category_icon,
    c.color as category_color,
    COUNT(mg.id) as goal_count,
    SUM(CASE WHEN mg.next_goal_trigger != 'auto' THEN 1 ELSE 0 END) as triggers_count,
    m.created_at,
    m.last_executed
FROM missions m
LEFT JOIN categories c ON m.category_id = c.id
LEFT JOIN mission_goals mg ON m.id = mg.mission_id
GROUP BY m.id, m.name, m.description, m.category_id, c.name, c.icon, c.color, m.created_at, m.last_executed;

-- Insert sample data untuk testing
INSERT INTO maps (name, resolution, origin_x, origin_y, width, height) VALUES 
('map_1', 0.05, -10.0, -10.0, 384, 384),
('map_2', 0.05, -5.0, -5.0, 200, 200);

INSERT INTO goal_sets (map_id, name, description, total_goals) VALUES 
(1, 'Goal Set 1', 'Sample goal set for map 1', 3),
(1, 'Goal Set 2', 'Another goal set for map 1', 4),
(2, 'Factory Points', 'Factory inspection points', 5);

INSERT INTO goals (goal_set_id, sequence_number, position_x, position_y, orientation_z, orientation_w) VALUES 
(1, 1, 1.0, 2.0, 0.707, 0.707),
(1, 2, 3.0, 4.0, 0.0, 1.0),
(1, 3, 5.0, 1.0, -0.707, 0.707),
(2, 1, 2.0, 3.0, 0.5, 0.866),
(2, 2, 4.0, 5.0, 0.0, 1.0),
(2, 3, 6.0, 2.0, -0.5, 0.866),
(2, 4, 8.0, 4.0, 0.866, 0.5),
(3, 1, 1.5, 2.5, 0.707, 0.707),
(3, 2, 3.5, 4.5, 0.0, 1.0),
(3, 3, 5.5, 1.5, -0.707, 0.707),
(3, 4, 7.5, 3.5, 0.866, 0.5),
(3, 5, 9.5, 5.5, 0.5, 0.866);

INSERT INTO categories (name, description, icon, color) VALUES 
('Inspection', 'Inspection missions', 'fas fa-search', '#10b981'),
('Delivery', 'Delivery missions', 'fas fa-shipping-fast', '#3b82f6'),
('Patrol', 'Patrol missions', 'fas fa-route', '#f59e0b'),
('Emergency', 'Emergency missions', 'fas fa-exclamation-triangle', '#ef4444');

-- Insert sample missions dengan triggers
INSERT INTO missions (name, description, category_id) VALUES 
('Factory Inspection', 'Daily factory inspection route', 1),
('Material Delivery', 'Delivery route from warehouse to station', 2),
('Security Patrol', 'Night security patrol route', 3);

-- Insert mission_goals dengan trigger data (sensor_condition tidak perlu diisi karena TEXT)
INSERT INTO mission_goals (mission_id, goal_id, sequence_number, next_goal_trigger, wait_time, timeout, retry_count, on_failure) VALUES 
(1, 1, 1, 'auto', 5, 60, 0, 'skip'),
(1, 2, 2, 'timer', 10, 120, 2, 'retry'),
(1, 3, 3, 'manual', 0, 300, 1, 'pause'),
(2, 4, 1, 'auto', 5, 60, 0, 'skip'),
(2, 5, 2, 'timer', 15, 180, 3, 'retry'),
(2, 6, 3, 'sensor', 0, 240, 2, 'stop'),
(2, 7, 4, 'manual', 0, 120, 0, 'skip'),
(3, 8, 1, 'auto', 5, 60, 0, 'skip'),
(3, 9, 2, 'timer', 30, 300, 1, 'retry'),
(3, 10, 3, 'sensor', 0, 180, 2, 'pause'),
(3, 11, 4, 'auto', 5, 60, 0, 'skip'),
(3, 12, 5, 'manual', 0, 240, 1, 'skip');

-- Stored Procedure: Get mission with full trigger details
DELIMITER //
CREATE PROCEDURE GetMissionWithTriggers(IN mission_id INT)
BEGIN
    -- Get mission basic info
    SELECT 
        m.id,
        m.name,
        m.description,
        m.category_id,
        c.name as category_name,
        c.icon as category_icon,
        c.color as category_color,
        m.created_at,
        m.last_executed
    FROM missions m
    LEFT JOIN categories c ON m.category_id = c.id
    WHERE m.id = mission_id;
    
    -- Get mission goals with trigger details
    SELECT 
        mg.id,
        mg.sequence_number,
        mg.next_goal_trigger,
        mg.wait_time,
        mg.sensor_type,
        mg.sensor_condition,
        mg.timeout,
        mg.retry_count,
        mg.on_failure,
        g.position_x,
        g.position_y,
        g.orientation_z,
        g.orientation_w,
        g.tolerance_xy,
        g.tolerance_yaw,
        g.created_at as goal_created_at,
        gs.name as goal_set_name,
        gs.id as goal_set_id,
        mp.name as map_name
    FROM mission_goals mg
    JOIN goals g ON mg.goal_id = g.id
    LEFT JOIN goal_sets gs ON g.goal_set_id = gs.id
    LEFT JOIN maps mp ON gs.map_id = mp.id
    WHERE mg.mission_id = mission_id
    ORDER BY mg.sequence_number;
END //
DELIMITER ;

-- Function: Count missions by category
DELIMITER //
CREATE FUNCTION CountMissionsByCategory(category_id INT) RETURNS INT
READS SQL DATA
BEGIN
    DECLARE mission_count INT;
    SELECT COUNT(*) INTO mission_count FROM missions WHERE category_id = category_id;
    RETURN mission_count;
END //
DELIMITER ;

-- Trigger: Update mission updated_at timestamp when mission_goals change
DELIMITER //
CREATE TRIGGER update_mission_timestamp
AFTER INSERT ON mission_goals
FOR EACH ROW
BEGIN
    UPDATE missions 
    SET updated_at = CURRENT_TIMESTAMP 
    WHERE id = NEW.mission_id;
END //
DELIMITER ;

-- Trigger: Update mission updated_at when mission_goals are deleted
DELIMITER //
CREATE TRIGGER update_mission_timestamp_on_delete
AFTER DELETE ON mission_goals
FOR EACH ROW
BEGIN
    UPDATE missions 
    SET updated_at = CURRENT_TIMESTAMP 
    WHERE id = OLD.mission_id;
END //
DELIMITER ;

-- Trigger: Update mission updated_at when mission_goals are updated
DELIMITER //
CREATE TRIGGER update_mission_timestamp_on_update
AFTER UPDATE ON mission_goals
FOR EACH ROW
BEGIN
    UPDATE missions 
    SET updated_at = CURRENT_TIMESTAMP 
    WHERE id = NEW.mission_id;
END //
DELIMITER ;

-- Event: Cleanup old unused goal sets (runs monthly)
DELIMITER //
CREATE EVENT IF NOT EXISTS cleanup_unused_goal_sets
ON SCHEDULE EVERY 1 MONTH
DO
BEGIN
    DELETE FROM goal_sets 
    WHERE id NOT IN (
        SELECT DISTINCT g.goal_set_id 
        FROM goals g
        JOIN mission_goals mg ON g.id = mg.goal_id
    )
    AND created_at < DATE_SUB(NOW(), INTERVAL 6 MONTH);
END //
DELIMITER ;

-- Set event scheduler ON (jika belum aktif)
SET GLOBAL event_scheduler = ON;