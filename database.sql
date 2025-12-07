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

-- Mission goals junction table
CREATE TABLE mission_goals (
    id INT PRIMARY KEY AUTO_INCREMENT,
    mission_id INT NOT NULL,
    goal_id INT NOT NULL,
    sequence_number INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (mission_id) REFERENCES missions(id) ON DELETE CASCADE,
    FOREIGN KEY (goal_id) REFERENCES goals(id) ON DELETE CASCADE,
    UNIQUE KEY unique_mission_goal (mission_id, goal_id),
    INDEX idx_mission_goals_mission (mission_id),
    INDEX idx_mission_goals_goal (goal_id),
    INDEX idx_mission_goals_sequence (sequence_number)
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