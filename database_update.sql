-- Categories table
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

-- Missions table (update)
ALTER TABLE missions
ADD COLUMN category_id INT DEFAULT 1,
ADD COLUMN last_executed TIMESTAMP NULL,
ADD FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET DEFAULT;

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
    INDEX idx_mission_goals_goal (goal_id)
);

-- Insert default category
INSERT INTO categories (name, description, icon, color) VALUES 
('Default', 'Default mission category', 'fas fa-folder', '#3b82f6');