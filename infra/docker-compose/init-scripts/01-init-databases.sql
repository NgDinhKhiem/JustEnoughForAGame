-- Initialize TicTacToe databases and users

-- Create databases
CREATE DATABASE IF NOT EXISTS tictactoe;
CREATE DATABASE IF NOT EXISTS tictactoe_test;

-- Create users and grant permissions
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'tictactoe_user') THEN
        CREATE ROLE tictactoe_user LOGIN PASSWORD 'tictactoe_pass';
    END IF;
END
$$;

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE tictactoe TO tictactoe_user;
GRANT ALL PRIVILEGES ON DATABASE tictactoe_test TO tictactoe_user;

-- Connect to tictactoe database and create initial schema
\c tictactoe;

-- Grant schema permissions
GRANT ALL ON SCHEMA public TO tictactoe_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO tictactoe_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO tictactoe_user;

-- Create initial tables (if needed for some services)
CREATE TABLE IF NOT EXISTS service_health (
    service_name VARCHAR(50) PRIMARY KEY,
    status VARCHAR(20) NOT NULL,
    last_check TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert initial health check data
INSERT INTO service_health (service_name, status) VALUES 
    ('auth-service', 'unknown'),
    ('user-service', 'unknown'),
    ('lobby-service', 'unknown'),
    ('game-service', 'unknown'),
    ('leaderboard-service', 'unknown'),
    ('analytics-service', 'unknown')
ON CONFLICT (service_name) DO NOTHING;
