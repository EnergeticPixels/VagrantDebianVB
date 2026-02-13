# 🐘 PostgreSQL Database Setup — Moodle User & Database

This Vagrant project is configured to automatically set up PostgreSQL with a dedicated Moodle user and database for development.

## Overview

The PostgreSQL setup includes:
- **PostgreSQL repository configuration** via `install_pg-common.sh`
- **Automatic Moodle user creation** with customizable credentials
- **Moodle database setup** with full user privileges
- **Environment-based configuration** using `.env` variables
- **Clean idempotent scripts** safe to run multiple times

## Scripts

### `install_pg-common.sh` — PostgreSQL Repository Setup

**Location:** `scripts/guest/install_pg-common.sh`

**What it does:**
1. Updates the system package lists
2. Installs `postgresql-common` package (required for version management)
3. Downloads and installs the official PostgreSQL signing key
4. Adds the PostgreSQL community repository (PGDG) to apt sources
5. Updates package lists to recognize PostgreSQL packages

**Why it's needed:**
- The default Debian repositories may have older PostgreSQL versions
- This enables installation of newer PostgreSQL versions (like PostgreSQL 15+)
- Sets up the foundation for installing specific PostgreSQL server versions

**When it runs:**
- Automatically during `vagrant up` (early in provisioning, before PostgreSQL server installation)
- Runs once; subsequent runs are safe and idempotent

**Key files modified:**
```
/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc  # Repository signing key
/etc/apt/sources.list.d/pgdg.list  # PostgreSQL PGDG repository configuration
```

---

### `install_moodle_db.sh` — Moodle Database & User Creation

**Location:** `scripts/guest/install_moodle_db.sh`

**What it does:**
1. Validates that postgres service is installed
2. Creates a PostgreSQL user with a secure password
3. Creates an empty `moodledb` database
4. Assigns the database to the moodle user (sets OWNER)
5. Grants all privileges to the moodle user on the database
6. Sets connection parameters for optimal performance
7. Displays connection details for reference

**Key features:**
- **Configurable credentials** — Username and password come from `.env` environment variables
- **Secure by default** — Generates a random password if none provided
- **Idempotent** — Safe to run multiple times; gives clear warnings if user/database already exists
- **Clear output** — Displays connection details and passwords in the provisioning logs
- **Error handling** — Validates PostgreSQL installation before attempting configuration

**When it runs:**
- Automatically during `vagrant up` (after PostgreSQL server installation)
- Can be manually re-run: `vagrant provision`
- Requires PostgreSQL to be installed first

**Generated resources:**
```
PostgreSQL User:      moodle
PostgreSQL Database:  moodledb
Owner/Permissions:    moodle user has full rights
Host:                 localhost (5432)
```

**Database Connection String Example:**
```
postgresql://moodle:password@localhost:5432/moodledb
```

---

## Vagrantfile Configuration

The following changes support PostgreSQL Moodle setup:

### 1. **PostgreSQL Server Installation**
```ruby
db_version = ENV['DB_VERSION'] || '15'

# Installs postgresql-<version> using the PGDG repository configured by install_pg-common.sh
sudo apt-get install -y postgresql-#{db_version}
```

The `DB_VERSION` environment variable (from `.env`) controls which PostgreSQL version is installed. Defaults to version 15 if not specified.

### 2. **Moodle Database Provisioner**
```ruby
config.vm.provision "shell", path: "scripts/guest/install_moodle_db.sh", args: [ENV['MOODLE_USER'], ENV['MOODLE_PASS']]
```
Runs the Moodle database setup script, passing credentials from `.env`.

---

## Environment Configuration

The setup uses variables from your `.env` file:

```bash
# .env
export BOX_NAME=boxen/debian-13
export WEB_DNS=web.local
export WEB_SERVER=apache
export DB_VERSION=15                  # ← PostgreSQL version to install
export DB_NEEDED=postgresql           # ← Database type flag
export MOODLE_USER=moodle             # ← Moodle PostgreSQL username
export MOODLE_PASS=moodle_secure_password_123  # ← Moodle PostgreSQL password
```

### Available Environment Variables

| Variable | Purpose | Default | Example |
|----------|---------|---------|---------|
| `DB_VERSION` | PostgreSQL major version to install | 15 | `13`, `14`, `15`, `16` |
| `DB_NEEDED` | Database system indicator | postgresql | postgresql |
| `MOODLE_USER` | PostgreSQL username for Moodle | moodle | myapp_user |
| `MOODLE_PASS` | PostgreSQL password for Moodle | (required) | your_secure_password |

### Changing PostgreSQL Version

Edit `.env` **before** running `vagrant up`:

```bash
# Install PostgreSQL 14 instead
export DB_VERSION=14
```

Then rebuild:
```bash
vagrant destroy -f
vagrant up
```

The PostgreSQL PGDG repository (installed by `install_pg-common.sh`) supports multiple versions, so any major version is available.

---

## Usage

### First-time Setup

```bash
vagrant up
```

**What to expect:**
1. VM boots
2. PostgreSQL repository is configured (`install_pg-common.sh`)
3. PostgreSQL 15 server is installed
4. Moodle user and database are created (`install_moodle_db.sh`)
5. Connection details are printed in provisioning logs

Look for this in the output:
```
[INFO] Moodle database setup completed successfully!
[INFO] Connection details:
[INFO]   - User: moodle
[INFO]   - Password: your_password_here
[INFO]   - Database: moodledb
[INFO]   - Host: localhost
[INFO]   - Port: 5432
```

### Connecting to the Moodle Database

**From within the guest:**
```bash
vagrant ssh
psql -U moodle -d moodledb -h localhost
```

Or with password prompt:
```bash
psql -U moodle -d moodledb -h localhost <password>
```

**From the host machine (if port forwarding configured):**
```bash
# Forward PostgreSQL port in Vagrantfile (if needed):
# config.vm.network "forwarded_port", guest: 5432, host: 5432

psql -U moodle -d moodledb -h 127.0.0.1
```

### Checking Moodle User & Database

**Inside the guest:**
```bash
vagrant ssh
sudo -u postgres psql
```

Then at the `psql>` prompt:
```sql
-- List all databases
\l

-- List all users/roles
\du

-- Connect to moodledb
\c moodledb

-- List tables (should be empty initially)
\dt
```

### Accessing Moodle Installation Files

Place your Moodle source code in the `app_data/` folder:

```bash
# Host machine
app_data/
└── moodledata/        # Your Moodle installation
    ├── admin/
    ├── course/
    ├── auth/
    └── config.php
```

This syncs to `/vagrant_data` in the guest.

---

## Troubleshooting

### ❌ "PostgreSQL is not installed"

**Symptom:** Script fails with "PostgreSQL is not installed. Please install PostgreSQL first."

**Solution:** Ensure `install_pg-common.sh` ran successfully. Check provisioning logs for errors in the PostgreSQL repository setup step.

### ❌ "User 'moodle' may already exist"

**Symptom:** Warning in provisioning logs about user already existing.

**Solution:** This is normal on `vagrant reload`. The user was created in the first run and already exists. You can safely ignore this warning.

### ❌ Cannot connect to moodledb from host

**Symptom:** `psql -h localhost -U moodle -d moodledb` fails from host machine.

**Cause:** PostgreSQL only listens on localhost inside the guest by default; the host port is not forwarded.

**Solution:** To connect from the host, add port forwarding to the Vagrantfile:
```ruby
config.vm.network "forwarded_port", guest: 5432, host: 5432
```

Then from the host:
```bash
psql -h 127.0.0.1 -U moodle -d moodledb
```

### ❌ Wrong password in `.env`

**Symptom:** Cannot connect to moodledb with the credentials.

**Solution:** Recreate the VM with the correct password:
1. Edit `.env` with the correct `MOODLE_PASS`
2. Run `vagrant destroy -f`
3. Run `vagrant up` again

### ❌ Need to reset the moodle user password

**From within the guest:**
```bash
vagrant ssh
sudo -u postgres psql -c "ALTER USER moodle WITH PASSWORD 'new_password';"
```

---

## How It Integrates with Vagrant Workflow

| Command | What Happens | Moodle DB Status |
|---------|-------------|------------------|
| `vagrant up` | First boot + provisioning | User & DB created ✓ |
| `vagrant halt` | Graceful shutdown | Database persists ✓ |
| `vagrant resume` | Boot (no provision) | Database intact ✓ |
| `vagrant reload` | Reboot + provision | Warnings if already exist (safe) |
| `vagrant reload --no-provision` | Reboot only | Database unchanged ✓ |
| `vagrant destroy` | Cleanup + remove VM | Database deleted with VM |

---

## Moodle-Specific Notes

### Connection in Moodle config.php

When installing Moodle, use these settings:

```php
$CFG->dbtype    = 'pgsql';                       // PostgreSQL
$CFG->dblibrary = 'native';                       // Native driver
$CFG->dbhost    = 'localhost';                   // Host inside guest
$CFG->dbname    = 'moodledb';                    // Database name
$CFG->dbuser    = 'moodle';                      // User from .env MOODLE_USER
$CFG->dbpass    = 'moodle_secure_password_123';  // Password from .env MOODLE_PASS
$CFG->dboptions = array(
    'dbpersist' => false,
    'dbsocket'  => false,
    'dbport'    => 5432,
);
```

### Database Initialization

Moodle will automatically:
1. Create all required tables on first installation
2. Populate schema based on Moodle version
3. Migrate data when upgrading versions

No additional database setup is needed beyond what this script provides.

---

## Related Files

- `scripts/guest/install_pg-common.sh` — PostgreSQL repository configuration
- `scripts/guest/install_moodle_db.sh` — Moodle user and database creation
- `Vagrantfile` — Vagrant configuration with PostgreSQL provisioning
- `.env` — Environment variables (including `MOODLE_USER` and `MOODLE_PASS`)
- `.env.sample` — Template for `.env`

---

## Notes

- The PostgreSQL setup is **automatic** — no manual user creation needed
- Credentials are configured entirely through environment variables in `.env`
- Both scripts are **idempotent** — safe to run during `vagrant reload`
- The `moodledb` database starts empty; Moodle will create its own schema
- Password generation uses OpenSSL for cryptographic strength
- All operations run with appropriate privileges (postgres user)

