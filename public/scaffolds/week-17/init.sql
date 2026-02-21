-- =============================================================================
-- PostgreSQL Initialization Script
-- =============================================================================
-- This script runs automatically when the PostgreSQL container starts for the
-- first time (mounted to /docker-entrypoint-initdb.d/).
--
-- It creates the tasks table used by the Flask API.
-- On subsequent starts, this script is skipped (data is already initialized).
-- =============================================================================

-- Create the tasks table
CREATE TABLE IF NOT EXISTS tasks (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert some sample data
INSERT INTO tasks (title, status) VALUES
    ('Set up the development environment', 'completed'),
    ('Learn Docker Compose', 'in_progress'),
    ('Deploy to production', 'pending'),
    ('Configure automated backups', 'pending'),
    ('Write architecture documentation', 'pending');

-- Verify the table was created
SELECT 'Database initialized successfully. Tasks table contains ' || COUNT(*) || ' rows.' AS status FROM tasks;
