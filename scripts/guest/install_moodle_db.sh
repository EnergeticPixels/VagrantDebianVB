#!/bin/bash

# Script: install_moodle_db.sh
# Description: Creates a PostgreSQL moodle user and moodledb database
# Usage: sudo ./install_moodle_db.sh [moodle_user] [moodle_password]
# If no arguments provided, defaults are used or password is generated

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

# Check if PostgreSQL is installed
if ! command -v psql &> /dev/null; then
    print_error "PostgreSQL is not installed. Please install PostgreSQL first."
    exit 1
fi

# Use provided arguments or defaults
MOODLE_USER="${1:-moodle}"
MOODLE_PASSWORD="${2:-}"

# Generate password if not provided
if [ -z "$MOODLE_PASSWORD" ]; then
    MOODLE_PASSWORD=$(openssl rand -base64 16)
    print_warning "No password provided. Generated password: $MOODLE_PASSWORD"
fi

MOODLE_DB="moodledb"

print_info "Starting Moodle database setup..."
print_info "User: $MOODLE_USER"
print_info "Database: $MOODLE_DB"

# Create the moodle user if it doesn't exist
print_info "Creating PostgreSQL user '$MOODLE_USER'..."
sudo -u postgres psql -c "CREATE USER $MOODLE_USER WITH PASSWORD '$MOODLE_PASSWORD';" 2>/dev/null || \
    print_warning "User '$MOODLE_USER' may already exist."

# Create the moodledb database if it doesn't exist
print_info "Creating database '$MOODLE_DB'..."
sudo -u postgres psql -c "CREATE DATABASE $MOODLE_DB OWNER $MOODLE_USER;" 2>/dev/null || \
    print_warning "Database '$MOODLE_DB' may already exist."

# Grant all privileges on moodledb to moodle user
print_info "Granting all privileges on '$MOODLE_DB' to '$MOODLE_USER'..."
sudo -u postgres psql -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE $MOODLE_DB TO $MOODLE_USER;"

# Set connection parameters for improved performance
print_info "Setting connection parameters..."
sudo -u postgres psql -d $MOODLE_DB -c "ALTER DATABASE $MOODLE_DB SET log_min_duration_statement = -1;"

print_info "Moodle database setup completed successfully!"
print_info "Connection details:"
print_info "  - User: $MOODLE_USER"
print_info "  - Password: $MOODLE_PASSWORD"
print_info "  - Database: $MOODLE_DB"
print_info "  - Host: localhost"
print_info "  - Port: 5432"

# Optional: Display the password again for easy copy/paste
echo ""
print_warning "SAVE YOUR PASSWORD: $MOODLE_PASSWORD"
echo ""
