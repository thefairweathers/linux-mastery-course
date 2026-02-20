# Week 13: Databases — PostgreSQL & MariaDB

> **Goal:** Install and configure database servers, perform essential SQL operations, manage users and permissions, back up and restore data, and connect a database to the API from Week 12 to build a complete three-tier application.

[← Previous Week](../week-12/README.md) · [Next Week →](../week-14/README.md)

---

## Table of Contents

| Section | Topic |
|---------|-------|
| 13.1 | [Why Databases Matter](#131-why-databases-matter) |
| 13.2 | [Relational Database Concepts](#132-relational-database-concepts) |
| 13.3 | [PostgreSQL vs MariaDB](#133-postgresql-vs-mariadb) |
| 13.4 | [PostgreSQL on Ubuntu](#134-postgresql-on-ubuntu) |
| 13.5 | [MariaDB on Rocky](#135-mariadb-on-rocky) |
| 13.6 | [Side-by-Side Administration](#136-side-by-side-administration) |
| 13.7 | [SQL Fundamentals: Creating Structure](#137-sql-fundamentals-creating-structure) |
| 13.8 | [SQL Fundamentals: Working with Data](#138-sql-fundamentals-working-with-data) |
| 13.9 | [JOINs: Querying Across Tables](#139-joins-querying-across-tables) |
| 13.10 | [Indexes and Schema Changes](#1310-indexes-and-schema-changes) |
| 13.11 | [Database Users and Permissions](#1311-database-users-and-permissions) |
| 13.12 | [Backup and Restore](#1312-backup-and-restore) |
| 13.13 | [Connecting to the Application Layer](#1313-connecting-to-the-application-layer) |
| 13.14 | [The Three-Tier Architecture](#1314-the-three-tier-architecture) |
| 13.15 | [Monitoring and Troubleshooting](#1315-monitoring-and-troubleshooting) |

---

## 13.1 Why Databases Matter

Every real application stores state. The Flask API you built in Week 12 could receive data through its `/api/echo` endpoint, but the moment that process stopped, every piece of data vanished. Restart the server, and you're starting from zero. That's fine for a demo. It's unacceptable for anything real.

Consider what actually needs to persist in production systems:

- User accounts and credentials
- Application data (orders, messages, configurations)
- Session state and tokens
- Audit logs and history

You could store this in flat files — and early web applications did exactly that. But flat files collapse under concurrent access, offer no query language, provide no transaction guarantees, and scale terribly. **Databases** solve all of these problems.

A database is a structured, persistent storage system that provides:

- **Concurrent access** — Multiple processes can read and write simultaneously without corrupting data
- **Query language** — You describe *what* data you want, not *how* to find it
- **ACID transactions** — Atomicity, Consistency, Isolation, Durability guarantee that your data stays correct even when things go wrong
- **Access control** — Fine-grained permissions on who can see and modify what

This week, we're installing two production-grade **relational database management systems (RDBMS)**: PostgreSQL on Ubuntu and MariaDB on Rocky. By the end, you'll connect PostgreSQL to the Flask API from Week 12 — transforming a stateless demo into a real three-tier application that persists data across restarts.

---

## 13.2 Relational Database Concepts

Before we touch any software, let's establish vocabulary. Every relational database uses the same core concepts.

### Tables, Rows, and Columns

A **table** is a named collection of data organized into rows and columns — much like a spreadsheet. But unlike a spreadsheet, every column has a defined data type, and the database enforces it.

```text
                            tasks
  ┌────┬──────────────────┬───────────┬─────────────────────┐
  │ id │ title            │ status    │ created_at          │
  ├────┼──────────────────┼───────────┼─────────────────────┤
  │  1 │ Install nginx    │ complete  │ 2025-01-15 09:00:00 │
  │  2 │ Configure SSL    │ pending   │ 2025-01-15 10:30:00 │
  │  3 │ Deploy API       │ active    │ 2025-01-15 14:00:00 │
  └────┴──────────────────┴───────────┴─────────────────────┘
```

Each horizontal entry is a **row** (also called a record or tuple). Each vertical category is a **column** (also called a field or attribute). The table has a **name** (`tasks`) that you use to reference it in queries.

### Primary Keys

A **primary key** is a column (or combination of columns) that uniquely identifies each row. No two rows can have the same primary key value, and it can never be NULL. In our example, `id` is the primary key — every task has a unique integer.

Most tables use an auto-incrementing integer as the primary key. PostgreSQL calls this `SERIAL`; MariaDB uses `AUTO_INCREMENT`.

### Foreign Keys

A **foreign key** is a column that references the primary key of another table, creating a relationship between them.

```text
  projects                         tasks
  ┌────┬──────────────┐            ┌────┬──────────────┬────────────┐
  │ id │ name         │            │ id │ title        │ project_id │
  ├────┼──────────────┤            ├────┼──────────────┼────────────┤
  │  1 │ Web Redesign │◄───────────│  1 │ Install nginx│     1      │
  │  2 │ API Launch   │◄───┐       │  2 │ Configure SSL│     1      │
  └────┴──────────────┘    └───────│  3 │ Deploy API   │     2      │
                                   └────┴──────────────┴────────────┘
```

Here, `tasks.project_id` is a foreign key referencing `projects.id`. The database can enforce this relationship — it will refuse to insert a task with a `project_id` that doesn't exist in the `projects` table. This is called **referential integrity**.

### Indexes

An **index** is a data structure that speeds up queries on specific columns, much like a book's index lets you find topics without reading every page. Without an index, the database must scan every row (a "full table scan"). With an index on the `status` column, a query like `WHERE status = 'pending'` can jump directly to matching rows.

The trade-off: indexes speed up reads but slow down writes (because the index must be updated on every INSERT, UPDATE, or DELETE). You'll learn when and where to add indexes in Section 13.10.

### Schemas

A **schema** is a namespace within a database. It's a way to organize tables into logical groups. PostgreSQL uses schemas extensively — every database has a default schema called `public`. MariaDB uses the terms "database" and "schema" interchangeably.

For most of this course, we'll work within the default schema. Just know that in large production systems, schemas provide important organizational boundaries.

---

## 13.3 PostgreSQL vs MariaDB

Both are open-source relational databases, both are production-ready, and both are widely deployed. But they have different histories, different strengths, and different operational characteristics.

### A Brief History

**PostgreSQL** began as a research project at UC Berkeley in 1986 (originally called "Postgres"). It was designed from the start with a focus on correctness, standards compliance, and extensibility. Today it's known for handling complex queries, advanced data types (JSON, arrays, full-text search), and strict data integrity.

**MariaDB** is a fork of MySQL, created in 2009 by MySQL's original author (Monty Widenius) after Oracle acquired Sun Microsystems and MySQL with it. MariaDB aims to remain fully open-source and drop-in compatible with MySQL while adding features and performance improvements. When people say "MySQL" in conversation, they often mean MariaDB — the two are largely interchangeable at the command level.

### Comparison Table

| Feature | PostgreSQL | MariaDB |
|---------|-----------|---------|
| Default port | 5432 | 3306 |
| License | PostgreSQL License (permissive, similar to MIT) | GPL v2 |
| Config directory | `/etc/postgresql/<ver>/main/` (Ubuntu) | `/etc/my.cnf`, `/etc/my.cnf.d/` |
| Data directory | `/var/lib/postgresql/<ver>/main/` | `/var/lib/mysql/` |
| Client tool | `psql` | `mariadb` (or `mysql`) |
| System user | `postgres` | `mysql` |
| Service name | `postgresql` | `mariadb` |
| Default auth | Peer authentication (local), md5/scram-sha-256 (remote) | Unix socket (local), password (remote) |
| Auto-increment | `SERIAL` / `GENERATED ALWAYS AS IDENTITY` | `AUTO_INCREMENT` |
| String concatenation | `\|\|` operator | `CONCAT()` function |
| Case sensitivity | Identifiers folded to lowercase unless quoted | Depends on OS (case-sensitive on Linux) |
| JSON support | Native `JSONB` type with indexing | JSON type (stored as text internally) |
| Replication | Built-in streaming replication | Built-in (multiple engines: Galera, InnoDB) |

### When to Choose Which

**Choose PostgreSQL when:**
- You need complex queries, CTEs (Common Table Expressions), or window functions
- Data integrity is paramount (financial, medical, government)
- You're working with JSON data alongside relational data
- You need advanced data types (arrays, hstore, range types)
- You want PostGIS for geospatial data

**Choose MariaDB when:**
- You're migrating from MySQL (drop-in compatibility)
- Your application was built against a MySQL driver
- You need a simpler operational model for basic CRUD workloads
- Your hosting environment provides MySQL/MariaDB by default
- You want Galera Cluster for multi-master replication

For this course, we'll install PostgreSQL on Ubuntu and MariaDB on Rocky. The three-tier application in the labs uses PostgreSQL because its `RETURNING` clause and `psycopg2` driver make Python integration particularly clean.

---

## 13.4 PostgreSQL on Ubuntu

### Installation

PostgreSQL is available in Ubuntu's default repositories:

```bash
sudo apt update
sudo apt install -y postgresql postgresql-contrib
```

The `postgresql-contrib` package adds useful extensions like `pg_stat_statements` (query performance tracking) and `uuid-ossp` (UUID generation).

Verify the service is running — remember `systemctl` from Week 11:

```bash
sudo systemctl status postgresql
```

```text
● postgresql.service - PostgreSQL RDBMS
     Loaded: loaded (/lib/systemd/system/postgresql.service; enabled; preset: enabled)
     Active: active (exited) since Mon 2025-01-20 10:00:00 UTC; 30s ago
```

Check the installed version:

```bash
psql --version
```

```text
psql (PostgreSQL) 16.4 (Ubuntu 16.4-1)
```

### How PostgreSQL Runs

PostgreSQL creates a dedicated system user called `postgres` during installation. This user owns the data files and runs the server process. Understanding this is key to connecting for the first time.

```bash
# The postgres system user
id postgres
```

```text
uid=113(postgres) gid=120(postgres) groups=120(postgres),119(ssl-cert)
```

The PostgreSQL server runs as the `postgres` user, and by default, it uses **peer authentication** for local connections — meaning the Linux user `postgres` can connect to PostgreSQL as the database user `postgres` without a password. Your regular user account cannot.

This is why the first connection always uses `sudo -u postgres`:

```bash
# Switch to postgres user and open the client
sudo -u postgres psql
```

```text
psql (16.4 (Ubuntu 16.4-1))
Type "help" for help.

postgres=#
```

The `postgres=#` prompt tells you two things: you're connected to the `postgres` database, and the `#` means you're a superuser.

### Configuration Files

PostgreSQL's configuration lives in a version-specific directory:

```bash
ls /etc/postgresql/16/main/
```

```text
conf.d  environment  pg_ctl.conf  pg_hba.conf  pg_ident.conf  postgresql.conf  start.conf
```

The two files you'll edit most often are:

| File | Purpose |
|------|---------|
| `postgresql.conf` | Server settings (memory, connections, logging, performance) |
| `pg_hba.conf` | Client authentication rules (who can connect from where) |

### postgresql.conf — Key Settings

```bash
sudo nano /etc/postgresql/16/main/postgresql.conf
```

The most important setting for network access:

```ini
# By default, PostgreSQL only listens on localhost
listen_addresses = 'localhost'     # Change to '*' or a specific IP for remote access

# Maximum number of simultaneous connections
max_connections = 100

# Default port
port = 5432
```

If you change `listen_addresses` to allow remote connections, you must also update `pg_hba.conf` — the two work together.

### pg_hba.conf — Authentication Rules

**pg_hba.conf** (host-based authentication) controls who can connect, from where, and how they authenticate. This file is read top to bottom — the first matching rule wins.

```bash
sudo nano /etc/postgresql/16/main/pg_hba.conf
```

Each line has the format:

```text
TYPE     DATABASE  USER      ADDRESS         METHOD
```

Here's what a typical default configuration looks like:

```text
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# Local connections (Unix domain socket)
local   all             postgres                                peer
local   all             all                                     peer

# IPv4 local connections
host    all             all             127.0.0.1/32            scram-sha-256

# IPv6 local connections
host    all             all             ::1/128                 scram-sha-256
```

Let's break down each field:

| Field | Values | Meaning |
|-------|--------|---------|
| TYPE | `local` | Unix socket connection (no network) |
| | `host` | TCP/IP connection (with or without SSL) |
| | `hostssl` | TCP/IP with SSL required |
| DATABASE | `all` | Any database |
| | `mydb` | Specific database name |
| USER | `all` | Any user |
| | `appuser` | Specific user |
| ADDRESS | `127.0.0.1/32` | Single IPv4 address (localhost) |
| | `192.168.1.0/24` | IPv4 subnet |
| | `0.0.0.0/0` | Any IPv4 address |
| METHOD | `peer` | Match OS username to database username (local only) |
| | `scram-sha-256` | Password authentication (recommended) |
| | `md5` | Password authentication (legacy, still common) |
| | `trust` | No authentication required (dangerous in production) |
| | `reject` | Always deny |

To allow remote connections from a specific subnet:

```text
# Allow app server at 192.168.1.100 to connect to taskdb as taskapp
host    taskdb          taskapp         192.168.1.100/32        scram-sha-256
```

After editing either config file, reload PostgreSQL:

```bash
sudo systemctl reload postgresql
```

Note: Some settings in `postgresql.conf` (like `listen_addresses`) require a full restart instead of a reload:

```bash
sudo systemctl restart postgresql
```

### The psql Client

`psql` is PostgreSQL's interactive terminal. It supports SQL commands and special backslash commands for metadata:

| Command | Purpose |
|---------|---------|
| `\l` | List all databases |
| `\c dbname` | Connect to a different database |
| `\dt` | List tables in the current schema |
| `\d tablename` | Describe a table (columns, types, indexes) |
| `\du` | List database users and roles |
| `\di` | List indexes |
| `\dn` | List schemas |
| `\?` | Help for backslash commands |
| `\h` | Help for SQL commands |
| `\h CREATE TABLE` | Detailed help for a specific SQL command |
| `\x` | Toggle expanded output (vertical display) |
| `\timing` | Toggle query execution time display |
| `\q` | Quit psql |

Let's try a few:

```bash
sudo -u postgres psql
```

```sql
-- List databases
\l
```

```text
                                                   List of databases
   Name    |  Owner   | Encoding | Locale Provider |   Collate   |    Ctype    |   Access privileges
-----------+----------+----------+-----------------+-------------+-------------+-----------------------
 postgres  | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |
 template0 | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |                 |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |                 |             |             | postgres=CTc/postgres
```

Three databases exist by default:
- `postgres` — the default admin database
- `template0` — a pristine template that should never be modified
- `template1` — the template used when creating new databases (changes here affect all new databases)

---

## 13.5 MariaDB on Rocky

### Installation

MariaDB is in Rocky's default AppStream repository:

```bash
sudo dnf install -y mariadb-server mariadb
```

Start and enable the service:

```bash
sudo systemctl enable --now mariadb
```

Verify:

```bash
sudo systemctl status mariadb
```

```text
● mariadb.service - MariaDB 10.5 database server
     Loaded: loaded (/usr/lib/systemd/system/mariadb.service; enabled; vendor preset: disabled)
     Active: active (running) since Mon 2025-01-20 10:05:00 UTC; 15s ago
```

### Securing the Installation

MariaDB ships with permissive defaults. The `mysql_secure_installation` script fixes the most common security issues:

```bash
sudo mysql_secure_installation
```

This interactive script walks you through several questions:

```text
Enter current password for root (enter for none): [Press Enter]
Switch to unix_socket authentication [Y/n]: Y
Change the root password? [Y/n]: Y
New password: ********
Remove anonymous users? [Y/n]: Y
Disallow root login remotely? [Y/n]: Y
Remove test database and access to it? [Y/n]: Y
Reload privilege tables now? [Y/n]: Y
```

Answer `Y` to all of these. Each one closes a different security hole:

| Question | Why It Matters |
|----------|---------------|
| Unix socket auth | Root authenticates by OS identity, not password |
| Remove anonymous users | Prevents connections without a username |
| Disallow remote root | Root can only connect from localhost |
| Remove test database | Removes a database that any user can access |
| Reload privileges | Applies changes immediately |

### Configuration Files

MariaDB reads its configuration from several locations, processed in order:

```bash
mariadb --help --verbose 2>/dev/null | head -20
```

```text
Default options are read from the following files in the given order:
/etc/my.cnf /etc/mysql/my.cnf ~/.my.cnf
```

The main file is `/etc/my.cnf`, which typically includes a directory:

```bash
cat /etc/my.cnf
```

```ini
[mysqld]
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
log-error=/var/log/mariadb/mariadb.log
pid-file=/run/mariadb/mariadb.pid

!includedir /etc/my.cnf.d
```

Key settings in `[mysqld]`:

| Setting | Default | Purpose |
|---------|---------|---------|
| `bind-address` | `0.0.0.0` | Which addresses to listen on |
| `port` | `3306` | TCP port |
| `datadir` | `/var/lib/mysql` | Where data files live |
| `max_connections` | `151` | Maximum simultaneous connections |
| `innodb_buffer_pool_size` | `128M` | InnoDB cache size (increase for production) |

### Connecting with the MariaDB Client

```bash
sudo mariadb
```

```text
Welcome to the MariaDB monitor.  Commands end with ; or \g.
MariaDB [(none)]>
```

The `(none)` means you haven't selected a database yet. Some useful commands:

```sql
-- List all databases
SHOW DATABASES;
```

```text
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| performance_schema |
+--------------------+
```

```sql
-- Switch to a database
USE mysql;

-- List tables in the current database
SHOW TABLES;

-- Describe a table's structure
DESCRIBE user;

-- Show the SQL that created a table
SHOW CREATE TABLE user\G

-- Exit
EXIT;
```

The `\G` at the end of a query displays results vertically — useful for wide tables.

---

## 13.6 Side-by-Side Administration

Having both databases fresh in your mind, here's a reference table comparing the most common administrative tasks:

| Task | PostgreSQL (Ubuntu) | MariaDB (Rocky) |
|------|-------------------|----------------|
| Install | `apt install postgresql` | `dnf install mariadb-server` |
| Start service | `systemctl start postgresql` | `systemctl start mariadb` |
| Connect as admin | `sudo -u postgres psql` | `sudo mariadb` |
| Config file | `/etc/postgresql/16/main/postgresql.conf` | `/etc/my.cnf` |
| Auth config | `/etc/postgresql/16/main/pg_hba.conf` | User table in `mysql` database |
| Data directory | `/var/lib/postgresql/16/main/` | `/var/lib/mysql/` |
| Log file | Via `journalctl -u postgresql` | `/var/log/mariadb/mariadb.log` |
| List databases | `\l` | `SHOW DATABASES;` |
| List tables | `\dt` | `SHOW TABLES;` |
| Describe table | `\d tablename` | `DESCRIBE tablename;` |
| List users | `\du` | `SELECT user, host FROM mysql.user;` |
| Reload config | `systemctl reload postgresql` | `systemctl reload mariadb` |
| Backup | `pg_dump dbname > file.sql` | `mysqldump dbname > file.sql` |
| Restore | `psql dbname < file.sql` | `mariadb dbname < file.sql` |

Keep this table handy. The concepts are identical — create databases, create users, grant permissions, query data. The syntax differs just enough to trip you up if you switch between them.

---

## 13.7 SQL Fundamentals: Creating Structure

**SQL** (Structured Query Language) is the standard language for relational databases. PostgreSQL and MariaDB both speak SQL, with minor dialect differences that we'll note as they come up.

SQL commands are grouped into categories:

| Category | Purpose | Key Commands |
|----------|---------|-------------|
| **DDL** (Data Definition Language) | Define structure | `CREATE`, `ALTER`, `DROP` |
| **DML** (Data Manipulation Language) | Work with data | `INSERT`, `SELECT`, `UPDATE`, `DELETE` |
| **DCL** (Data Control Language) | Manage access | `GRANT`, `REVOKE` |
| **TCL** (Transaction Control Language) | Manage transactions | `BEGIN`, `COMMIT`, `ROLLBACK` |

Let's start with DDL — creating the structures that hold our data.

### CREATE DATABASE

```sql
-- PostgreSQL
CREATE DATABASE taskdb;

-- MariaDB (identical)
CREATE DATABASE taskdb;
```

In psql, you can also use a shortcut:

```bash
sudo -u postgres createdb taskdb
```

### CREATE TABLE

Here's where it gets interesting. Every column has a name and a data type. Choosing the right type matters for storage efficiency, query performance, and data correctness.

```sql
-- PostgreSQL
CREATE TABLE tasks (
    id          SERIAL PRIMARY KEY,
    title       VARCHAR(200) NOT NULL,
    description TEXT,
    status      VARCHAR(20) NOT NULL DEFAULT 'pending',
    priority    INTEGER DEFAULT 0,
    is_active   BOOLEAN DEFAULT true,
    due_date    TIMESTAMP,
    created_at  TIMESTAMP DEFAULT NOW()
);

-- MariaDB
CREATE TABLE tasks (
    id          INTEGER AUTO_INCREMENT PRIMARY KEY,
    title       VARCHAR(200) NOT NULL,
    description TEXT,
    status      VARCHAR(20) NOT NULL DEFAULT 'pending',
    priority    INTEGER DEFAULT 0,
    is_active   BOOLEAN DEFAULT true,
    due_date    TIMESTAMP NULL,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

Let's break down each constraint:

| Constraint | Meaning |
|-----------|---------|
| `PRIMARY KEY` | Unique, non-null identifier for each row |
| `NOT NULL` | This column cannot be empty |
| `DEFAULT 'pending'` | If no value is provided, use this |
| `SERIAL` / `AUTO_INCREMENT` | Automatically assign the next integer |

### Data Type Comparison

The types are mostly the same, but there are differences worth knowing:

| Purpose | PostgreSQL | MariaDB | Notes |
|---------|-----------|---------|-------|
| Auto-increment integer | `SERIAL` | `INTEGER AUTO_INCREMENT` | PostgreSQL also supports `GENERATED ALWAYS AS IDENTITY` |
| Small integer | `SMALLINT` | `SMALLINT` | 2 bytes, -32768 to 32767 |
| Regular integer | `INTEGER` | `INTEGER` or `INT` | 4 bytes, ~2 billion range |
| Large integer | `BIGINT` | `BIGINT` | 8 bytes |
| Exact decimal | `DECIMAL(10,2)` or `NUMERIC(10,2)` | `DECIMAL(10,2)` | Use for money — never use FLOAT for money |
| Floating point | `REAL` / `DOUBLE PRECISION` | `FLOAT` / `DOUBLE` | Approximate — subject to rounding |
| Short string | `VARCHAR(n)` | `VARCHAR(n)` | Variable length, max n characters |
| Long text | `TEXT` | `TEXT` | Unlimited length (practically) |
| Boolean | `BOOLEAN` (`true`/`false`) | `BOOLEAN` (`TINYINT(1)`: 0/1) | MariaDB stores booleans as integers |
| Date only | `DATE` | `DATE` | YYYY-MM-DD |
| Date and time | `TIMESTAMP` | `TIMESTAMP` or `DATETIME` | MariaDB's TIMESTAMP has special auto-update behavior |
| UUID | `UUID` (native type) | `CHAR(36)` or `UUID()` function | PostgreSQL has a real UUID type |
| JSON | `JSON` / `JSONB` (binary, indexable) | `JSON` (stored as text) | PostgreSQL's JSONB is significantly more powerful |

> **Important:** Never use `FLOAT` or `DOUBLE` for monetary values. Floating-point arithmetic introduces rounding errors. Use `DECIMAL(10,2)` for money — it stores exact values.

### Tables with Foreign Keys

Let's create a second table that references the first:

```sql
-- PostgreSQL
CREATE TABLE projects (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    created_at  TIMESTAMP DEFAULT NOW()
);

-- Add a foreign key column to tasks
-- (In practice, you'd design this from the start)
ALTER TABLE tasks ADD COLUMN project_id INTEGER REFERENCES projects(id);
```

The `REFERENCES projects(id)` clause creates a foreign key constraint. The database will reject any INSERT or UPDATE that sets `project_id` to a value that doesn't exist in `projects.id`.

### DROP TABLE

```sql
-- Remove a table (IRREVERSIBLE)
DROP TABLE tasks;

-- Remove only if it exists (avoids error)
DROP TABLE IF EXISTS tasks;
```

`DROP TABLE` is permanent. There is no undo. In production, use backups (Section 13.12) before any destructive operation.

---

## 13.8 SQL Fundamentals: Working with Data

Now let's populate tables and query them. This is DML — the SQL you'll use most often.

### INSERT INTO

```sql
-- Insert a single row
INSERT INTO tasks (title, status) VALUES ('Install PostgreSQL', 'complete');

-- Insert with more columns
INSERT INTO tasks (title, description, status, priority)
VALUES ('Configure pg_hba.conf', 'Allow remote connections from app server', 'pending', 2);

-- Insert multiple rows at once
INSERT INTO tasks (title, status) VALUES
    ('Set up backups', 'pending'),
    ('Create app user', 'pending'),
    ('Write API endpoints', 'active');
```

Notice that we don't specify `id` or `created_at` — they have defaults (`SERIAL` and `NOW()`).

### PostgreSQL's RETURNING Clause

PostgreSQL has a powerful feature that MariaDB lacks — `RETURNING`:

```sql
-- Insert a row and get it back immediately
INSERT INTO tasks (title, status) VALUES ('Deploy to production', 'pending')
RETURNING id, title, status, created_at;
```

```text
 id |        title         | status  |         created_at
----+----------------------+---------+----------------------------
  6 | Deploy to production | pending | 2025-01-20 10:30:00.000000
```

This eliminates the need for a separate SELECT after inserting. You'll see this used heavily in our Flask API.

### SELECT

The `SELECT` statement retrieves data. It's the most versatile SQL command.

```sql
-- Select all columns, all rows
SELECT * FROM tasks;

-- Select specific columns
SELECT id, title, status FROM tasks;

-- Filter with WHERE
SELECT * FROM tasks WHERE status = 'pending';

-- Multiple conditions
SELECT * FROM tasks WHERE status = 'pending' AND priority > 1;
SELECT * FROM tasks WHERE status = 'complete' OR status = 'active';

-- Pattern matching with LIKE
SELECT * FROM tasks WHERE title LIKE '%PostgreSQL%';
-- % matches any sequence of characters
-- _ matches a single character

-- NULL checks (use IS NULL, not = NULL)
SELECT * FROM tasks WHERE due_date IS NULL;
SELECT * FROM tasks WHERE due_date IS NOT NULL;
```

### Sorting and Limiting

```sql
-- Order by column (ascending is default)
SELECT * FROM tasks ORDER BY created_at;

-- Descending order
SELECT * FROM tasks ORDER BY priority DESC;

-- Multiple sort columns
SELECT * FROM tasks ORDER BY status ASC, priority DESC;

-- Limit results
SELECT * FROM tasks ORDER BY created_at DESC LIMIT 5;

-- Offset (skip first N rows) — useful for pagination
SELECT * FROM tasks ORDER BY id LIMIT 10 OFFSET 20;
```

### Aggregate Functions

Aggregates compute a single value from multiple rows:

```sql
-- Count all rows
SELECT COUNT(*) FROM tasks;

-- Count rows matching a condition
SELECT COUNT(*) FROM tasks WHERE status = 'pending';

-- Sum of a numeric column
SELECT SUM(priority) FROM tasks;

-- Average
SELECT AVG(priority) FROM tasks;

-- Minimum and maximum
SELECT MIN(created_at), MAX(created_at) FROM tasks;
```

### GROUP BY

`GROUP BY` splits rows into groups and applies aggregate functions to each group:

```sql
-- Count tasks by status
SELECT status, COUNT(*) AS task_count
FROM tasks
GROUP BY status;
```

```text
  status  | task_count
----------+-----------
 pending  |         3
 complete |         1
 active   |         2
```

The `AS` keyword creates an alias for the computed column.

```sql
-- Average priority by status, only show groups with more than 1 task
SELECT status, COUNT(*) AS task_count, AVG(priority) AS avg_priority
FROM tasks
GROUP BY status
HAVING COUNT(*) > 1;
```

`HAVING` filters groups (after aggregation), while `WHERE` filters individual rows (before aggregation).

### UPDATE

```sql
-- Update a specific row
UPDATE tasks SET status = 'complete' WHERE id = 2;

-- Update multiple columns
UPDATE tasks SET status = 'active', priority = 5 WHERE id = 3;

-- Update multiple rows at once
UPDATE tasks SET priority = 0 WHERE status = 'complete';
```

> **The most dangerous statement in SQL is an UPDATE or DELETE without a WHERE clause.** It affects every row in the table. Always write your WHERE clause first, test it with a SELECT, then convert to UPDATE or DELETE.

```sql
-- DANGEROUS: Updates every row in the table!
UPDATE tasks SET status = 'archived';

-- Safe approach: verify first
SELECT * FROM tasks WHERE status = 'complete';
-- Then update
UPDATE tasks SET status = 'archived' WHERE status = 'complete';
```

PostgreSQL supports `RETURNING` on UPDATE too:

```sql
UPDATE tasks SET status = 'complete' WHERE id = 3 RETURNING *;
```

### DELETE

```sql
-- Delete a specific row
DELETE FROM tasks WHERE id = 4;

-- Delete rows matching a condition
DELETE FROM tasks WHERE status = 'archived';

-- DANGEROUS: Deletes ALL rows!
DELETE FROM tasks;
```

The same safety principle applies: always verify with a SELECT before running DELETE.

### Transactions

A **transaction** groups multiple statements into an atomic unit — either all succeed or all are rolled back:

```sql
-- Start a transaction
BEGIN;

-- These two operations are atomic
UPDATE tasks SET status = 'active' WHERE id = 1;
INSERT INTO tasks (title, status) VALUES ('Monitor deployment', 'pending');

-- If everything looks good
COMMIT;

-- Or if something went wrong
ROLLBACK;
```

If the connection drops mid-transaction, the database automatically rolls back. This is the "A" in ACID — Atomicity.

---

## 13.9 JOINs: Querying Across Tables

The real power of relational databases emerges when you query across multiple tables. **JOINs** combine rows from two or more tables based on a related column.

### Setting Up Example Data

```sql
-- Create projects table (if not already done)
CREATE TABLE projects (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    created_at  TIMESTAMP DEFAULT NOW()
);

INSERT INTO projects (name) VALUES ('Web Redesign'), ('API Launch'), ('Documentation');

-- Ensure tasks have a project_id column
ALTER TABLE tasks ADD COLUMN project_id INTEGER REFERENCES projects(id);

-- Assign some tasks to projects
UPDATE tasks SET project_id = 1 WHERE id IN (1, 2);
UPDATE tasks SET project_id = 2 WHERE id IN (3, 4);
-- Task 5 intentionally has no project (NULL project_id)
```

### INNER JOIN

An **INNER JOIN** returns only rows that have matching values in both tables:

```sql
SELECT tasks.id, tasks.title, tasks.status, projects.name AS project_name
FROM tasks
INNER JOIN projects ON tasks.project_id = projects.id;
```

```text
 id |        title         | status   | project_name
----+----------------------+----------+--------------
  1 | Install PostgreSQL   | complete | Web Redesign
  2 | Configure pg_hba.conf| pending  | Web Redesign
  3 | Set up backups       | pending  | API Launch
  4 | Create app user      | active   | API Launch
```

Notice that task 5 (with no `project_id`) is not included — INNER JOIN excludes rows with no match. Also notice that project 3 ("Documentation") doesn't appear because no tasks reference it.

### LEFT JOIN

A **LEFT JOIN** returns all rows from the left table, plus matching rows from the right table. Where there's no match, the right side is NULL:

```sql
SELECT tasks.id, tasks.title, projects.name AS project_name
FROM tasks
LEFT JOIN projects ON tasks.project_id = projects.id;
```

```text
 id |         title           | project_name
----+-------------------------+--------------
  1 | Install PostgreSQL      | Web Redesign
  2 | Configure pg_hba.conf   | Web Redesign
  3 | Set up backups          | API Launch
  4 | Create app user         | API Launch
  5 | Write API endpoints     | NULL
```

Now task 5 appears with a NULL project name. LEFT JOIN is useful when you want "all items, even those without a relationship."

To find all projects including those with no tasks:

```sql
SELECT projects.name, COUNT(tasks.id) AS task_count
FROM projects
LEFT JOIN tasks ON projects.id = tasks.project_id
GROUP BY projects.name;
```

```text
     name      | task_count
---------------+-----------
 Web Redesign  |         2
 API Launch    |         2
 Documentation |         0
```

### Table Aliases

To avoid typing full table names repeatedly, use aliases:

```sql
SELECT t.id, t.title, p.name AS project_name
FROM tasks t
INNER JOIN projects p ON t.project_id = p.id
WHERE t.status = 'pending'
ORDER BY p.name, t.title;
```

This is equivalent to the INNER JOIN example above but more concise.

---

## 13.10 Indexes and Schema Changes

### CREATE INDEX

As your tables grow, queries slow down without indexes. An index on a column lets the database find rows without scanning the entire table.

```sql
-- Create an index on the status column
CREATE INDEX idx_tasks_status ON tasks(status);

-- Create an index on multiple columns (composite index)
CREATE INDEX idx_tasks_status_priority ON tasks(status, priority);

-- Create a unique index (also enforces uniqueness)
CREATE UNIQUE INDEX idx_projects_name ON projects(name);
```

When to create indexes:

| Create Index On | When |
|----------------|------|
| Columns in WHERE clauses | `WHERE status = 'pending'` — frequent filter |
| Columns in JOIN conditions | `ON tasks.project_id = projects.id` |
| Columns in ORDER BY | `ORDER BY created_at DESC` — frequent sort |
| Foreign key columns | Almost always — both databases benefit |

When NOT to create indexes:
- On tiny tables (a few hundred rows) — full scan is faster than index lookup
- On columns that are rarely queried
- On tables that are heavily written and rarely read

View existing indexes:

```sql
-- PostgreSQL
\di

-- MariaDB
SHOW INDEX FROM tasks;
```

### ALTER TABLE

Schemas evolve as applications grow. `ALTER TABLE` lets you modify existing tables:

```sql
-- Add a new column
ALTER TABLE tasks ADD COLUMN assigned_to VARCHAR(100);

-- Remove a column
ALTER TABLE tasks DROP COLUMN assigned_to;

-- Rename a column (PostgreSQL)
ALTER TABLE tasks RENAME COLUMN title TO task_title;

-- Rename a column (MariaDB)
ALTER TABLE tasks CHANGE title task_title VARCHAR(200) NOT NULL;

-- Change a column's type (PostgreSQL)
ALTER TABLE tasks ALTER COLUMN status TYPE VARCHAR(50);

-- Change a column's type (MariaDB)
ALTER TABLE tasks MODIFY COLUMN status VARCHAR(50) NOT NULL DEFAULT 'pending';

-- Add a constraint
ALTER TABLE tasks ADD CONSTRAINT chk_status
    CHECK (status IN ('pending', 'active', 'complete', 'archived'));

-- Rename a table
ALTER TABLE tasks RENAME TO project_tasks;
```

> **Production caution:** Some ALTER TABLE operations lock the table, blocking reads and writes. On large tables, this can cause downtime. In production, use tools like `pg_repack` (PostgreSQL) or `pt-online-schema-change` (MariaDB/MySQL) for lock-free schema changes.

---

## 13.11 Database Users and Permissions

Never run your application as the database superuser. This is the same principle of least privilege you learned in Week 5 for Linux users — give each user only the permissions they need.

### PostgreSQL User Management

PostgreSQL uses the term **role** for both users and groups. A role with login permission is effectively a user.

```sql
-- Connect as the postgres superuser
sudo -u postgres psql

-- Create a role that can log in (i.e., a user) with a password
CREATE ROLE taskapp WITH LOGIN PASSWORD 'secure_password_here';

-- Verify
\du
```

```text
                                   List of roles
 Role name |                         Attributes
-----------+------------------------------------------------------------
 postgres  | Superuser, Create role, Create DB, Replication, Bypass RLS
 taskapp   |
```

Now grant permissions on a specific database and its tables:

```sql
-- Grant permission to connect to the database
GRANT CONNECT ON DATABASE taskdb TO taskapp;

-- Switch to the database
\c taskdb

-- Grant usage on the schema
GRANT USAGE ON SCHEMA public TO taskapp;

-- Grant specific table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO taskapp;

-- Grant usage on sequences (needed for SERIAL/auto-increment columns)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO taskapp;

-- Make these grants apply to future tables too
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO taskapp;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO taskapp;
```

Notice what we did NOT grant:
- `CREATE` — the app user cannot create or drop tables
- `TRUNCATE` — the app user cannot wipe tables
- No superuser, create role, or create database privileges

This means even if the application is compromised, the attacker cannot alter the database schema or access other databases.

Test the connection:

```bash
psql -h localhost -U taskapp -d taskdb
```

Enter the password when prompted. The prompt should show `taskdb=>` (note `>` not `#` — you're not a superuser).

### MariaDB User Management

```sql
-- Connect as root
sudo mariadb

-- Create a user (specify which hosts can connect)
CREATE USER 'taskapp'@'localhost' IDENTIFIED BY 'secure_password_here';

-- For remote connections, specify the host or use % for any
CREATE USER 'taskapp'@'192.168.1.%' IDENTIFIED BY 'secure_password_here';

-- Grant specific permissions on a database
GRANT SELECT, INSERT, UPDATE, DELETE ON taskdb.* TO 'taskapp'@'localhost';

-- Apply the changes
FLUSH PRIVILEGES;

-- Verify
SELECT user, host FROM mysql.user;
SHOW GRANTS FOR 'taskapp'@'localhost';
```

```text
+----------+-----------+
| user     | host      |
+----------+-----------+
| root     | localhost |
| taskapp  | localhost |
+----------+-----------+
```

Note that MariaDB ties permissions to a specific user-host combination. `'taskapp'@'localhost'` and `'taskapp'@'192.168.1.100'` are different users. This is unlike PostgreSQL, where `pg_hba.conf` controls host-based access separately from user creation.

### Permission Reference

| Permission | Allows | Application Needs? |
|-----------|--------|-------------------|
| `SELECT` | Read data | Yes |
| `INSERT` | Add rows | Yes |
| `UPDATE` | Modify rows | Yes |
| `DELETE` | Remove rows | Usually yes |
| `CREATE` | Create tables/indexes | No — admin only |
| `DROP` | Remove tables | No — admin only |
| `ALTER` | Modify table structure | No — admin only |
| `GRANT` | Delegate permissions | No — admin only |
| `ALL PRIVILEGES` | Everything | Never for app users |

The principle is simple: your application user gets SELECT, INSERT, UPDATE, and DELETE on its own tables. Everything else belongs to an admin user that humans use for maintenance.

---

## 13.12 Backup and Restore

Databases without backups are ticking time bombs. A stray `DELETE FROM tasks;` (no WHERE clause), a disk failure, or a ransomware attack — any of these can destroy years of data in seconds.

### PostgreSQL: pg_dump and pg_restore

`pg_dump` creates a logical backup — a file containing SQL commands to recreate the database:

```bash
# Dump a database to a SQL file (plaintext)
sudo -u postgres pg_dump taskdb > /tmp/taskdb_backup.sql

# Dump in custom format (compressed, supports parallel restore)
sudo -u postgres pg_dump -Fc taskdb > /tmp/taskdb_backup.dump

# Dump only specific tables
sudo -u postgres pg_dump -t tasks taskdb > /tmp/tasks_only.sql

# Dump only the schema (no data)
sudo -u postgres pg_dump --schema-only taskdb > /tmp/taskdb_schema.sql

# Dump only the data (no schema)
sudo -u postgres pg_dump --data-only taskdb > /tmp/taskdb_data.sql
```

Restore from a backup:

```bash
# Restore from a plain SQL file
sudo -u postgres psql taskdb < /tmp/taskdb_backup.sql

# Restore from custom format
sudo -u postgres pg_restore -d taskdb /tmp/taskdb_backup.dump

# Restore into a new database
sudo -u postgres createdb taskdb_restored
sudo -u postgres pg_restore -d taskdb_restored /tmp/taskdb_backup.dump
```

Dump all databases at once:

```bash
sudo -u postgres pg_dumpall > /tmp/all_databases.sql
```

### MariaDB: mysqldump

```bash
# Dump a database
sudo mysqldump taskdb > /tmp/taskdb_backup.sql

# Dump with specific user
mysqldump -u root -p taskdb > /tmp/taskdb_backup.sql

# Dump specific tables
sudo mysqldump taskdb tasks > /tmp/tasks_only.sql

# Dump all databases
sudo mysqldump --all-databases > /tmp/all_databases.sql

# Dump with routines (stored procedures) and triggers
sudo mysqldump --routines --triggers taskdb > /tmp/taskdb_full.sql
```

Restore:

```bash
# Restore from a SQL file
sudo mariadb taskdb < /tmp/taskdb_backup.sql

# Restore all databases
sudo mariadb < /tmp/all_databases.sql
```

### Automating Backups

In Week 9, you learned about cron. In Week 11, you learned about systemd timers. Either one can automate backups. Here's a practical script:

```bash
#!/bin/bash
# /usr/local/bin/backup-postgresql.sh
# Daily PostgreSQL backup with rotation

BACKUP_DIR="/var/backups/postgresql"
RETENTION_DAYS=7
DATE=$(date +%Y%m%d_%H%M%S)
DB_NAME="taskdb"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Create the backup
sudo -u postgres pg_dump -Fc "$DB_NAME" > "${BACKUP_DIR}/${DB_NAME}_${DATE}.dump"

# Check if backup succeeded
if [ $? -eq 0 ]; then
    echo "Backup successful: ${DB_NAME}_${DATE}.dump"
else
    echo "ERROR: Backup failed for ${DB_NAME}" >&2
    exit 1
fi

# Remove backups older than retention period
find "$BACKUP_DIR" -name "*.dump" -mtime +"$RETENTION_DAYS" -delete

echo "Backup complete. Remaining backups:"
ls -lh "$BACKUP_DIR"
```

Make it executable and schedule it:

```bash
sudo chmod +x /usr/local/bin/backup-postgresql.sh

# Add to crontab (daily at 2 AM)
echo "0 2 * * * /usr/local/bin/backup-postgresql.sh >> /var/log/pg-backup.log 2>&1" | sudo tee -a /var/spool/cron/crontabs/root
```

Or create a systemd timer (the approach from Week 11):

```ini
# /etc/systemd/system/pg-backup.service
[Unit]
Description=PostgreSQL daily backup

[Service]
Type=oneshot
ExecStart=/usr/local/bin/backup-postgresql.sh
User=root
```

```ini
# /etc/systemd/system/pg-backup.timer
[Unit]
Description=Run PostgreSQL backup daily at 2 AM

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now pg-backup.timer
```

### Backup Comparison

| Feature | pg_dump / pg_restore | mysqldump |
|---------|---------------------|-----------|
| Default output | SQL text | SQL text |
| Compressed format | `-Fc` (custom) or `-Fd` (directory) | Pipe through `gzip` |
| Parallel dump | `-j N` (directory format only) | Not built-in |
| Parallel restore | `-j N` (custom or directory format) | Not built-in |
| Point-in-time recovery | WAL archiving (advanced) | Binary log (advanced) |
| Dump while active | Yes (uses MVCC snapshots) | Use `--single-transaction` for InnoDB |

---

## 13.13 Connecting to the Application Layer

Now we bridge the gap between the database and the Flask API you built in Week 12. That API served static JSON responses and echoed back data. This week, we give it a real database.

### psycopg2: The Python PostgreSQL Adapter

**psycopg2** is the most popular PostgreSQL adapter for Python. Install it:

```bash
pip install psycopg2-binary
```

The `-binary` variant includes precompiled C libraries. In production, you'd install the non-binary version (`psycopg2`) and build it against your system's `libpq`, but the binary version is perfect for learning.

### Basic Connection Pattern

```python
import psycopg2

# Connect to the database
conn = psycopg2.connect(
    host="localhost",
    database="taskdb",
    user="taskapp",
    password="secure_password_here",
    port="5432"
)

# Create a cursor to execute queries
cur = conn.cursor()

# Execute a query
cur.execute("SELECT * FROM tasks WHERE status = %s", ("pending",))

# Fetch results
rows = cur.fetchall()
for row in rows:
    print(row)

# Clean up
cur.close()
conn.close()
```

### Parameterized Queries — Preventing SQL Injection

**Never** build SQL strings by concatenating user input. This is how SQL injection attacks work:

```python
# DANGEROUS — vulnerable to SQL injection
title = request.form["title"]
cur.execute(f"INSERT INTO tasks (title) VALUES ('{title}')")
# If title is: '); DROP TABLE tasks; --
# The database executes: INSERT INTO tasks (title) VALUES (''); DROP TABLE tasks; --')
```

Always use parameterized queries:

```python
# SAFE — parameterized query
title = request.form["title"]
cur.execute("INSERT INTO tasks (title) VALUES (%s)", (title,))
```

The `%s` is a placeholder — psycopg2 handles escaping and quoting. The second argument is a tuple of values (note the trailing comma for single-element tuples).

### Environment Variables for Credentials

Never hardcode database credentials in your source code. Use environment variables, just like the `PORT` variable in Week 12's app.py:

```python
import os

conn = psycopg2.connect(
    host=os.environ.get("DB_HOST", "localhost"),
    database=os.environ.get("DB_NAME", "taskdb"),
    user=os.environ.get("DB_USER", "taskapp"),
    password=os.environ.get("DB_PASS", ""),
    port=os.environ.get("DB_PORT", "5432")
)
```

Set these before starting your application:

```bash
export DB_HOST=localhost
export DB_NAME=taskdb
export DB_USER=taskapp
export DB_PASS=secure_password_here
```

For a systemd service (as you learned in Week 11), put them in an environment file:

```bash
# /opt/taskapi/.env
DB_HOST=localhost
DB_NAME=taskdb
DB_USER=taskapp
DB_PASS=secure_password_here
DB_PORT=5432
```

```ini
# In the service unit
[Service]
EnvironmentFile=/opt/taskapi/.env
```

### Dictionary Cursors

By default, psycopg2 returns rows as tuples. For a JSON API, dictionaries are much more convenient:

```python
import psycopg2.extras

cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
cur.execute("SELECT id, title, status FROM tasks")
tasks = cur.fetchall()
# [{'id': 1, 'title': 'Install PostgreSQL', 'status': 'complete'}, ...]
```

This makes it trivial to pass results directly to Flask's `jsonify()`.

---

## 13.14 The Three-Tier Architecture

With a database, a Flask API, and the nginx reverse proxy from Week 12, we now have all three layers of a classic **three-tier architecture**:

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                         CLIENT (Browser / curl)                         │
│                                                                         │
│   curl http://your-server/api/tasks                                     │
└────────────────────────────┬────────────────────────────────────────────┘
                             │ HTTP request on port 80
                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    TIER 1: WEB SERVER (nginx)                           │
│                                                                         │
│   - Receives HTTP requests on port 80/443                              │
│   - Serves static files directly                                        │
│   - Proxies API requests to Flask (proxy_pass http://127.0.0.1:8080)   │
│   - Handles SSL termination (in production)                             │
│   - Provides load balancing (multiple app instances)                    │
└────────────────────────────┬────────────────────────────────────────────┘
                             │ Proxied request to 127.0.0.1:8080
                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    TIER 2: APPLICATION (Flask API)                       │
│                                                                         │
│   - Receives requests from nginx on port 8080                          │
│   - Contains business logic (validation, processing)                    │
│   - Connects to PostgreSQL using psycopg2                              │
│   - Returns JSON responses                                              │
│   - Reads DB credentials from environment variables                     │
└────────────────────────────┬────────────────────────────────────────────┘
                             │ SQL queries on port 5432
                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    TIER 3: DATABASE (PostgreSQL)                         │
│                                                                         │
│   - Stores and retrieves persistent data                               │
│   - Enforces data integrity (types, constraints, foreign keys)         │
│   - Handles concurrent access (MVCC)                                    │
│   - Manages transactions (ACID)                                         │
│   - Listens on port 5432 (localhost only, per pg_hba.conf)             │
└─────────────────────────────────────────────────────────────────────────┘
```

### How a Request Flows

Let's trace what happens when a client creates a new task:

1. **Client** sends: `curl -X POST http://your-server/api/tasks -H "Content-Type: application/json" -d '{"title": "Deploy v2"}'`
2. **nginx** receives the request on port 80. The `/api/` location block matches, so nginx proxies the request to `127.0.0.1:8080`
3. **Flask** receives the POST request. It validates the JSON body, extracts the title, and opens a database connection
4. **PostgreSQL** receives the SQL query: `INSERT INTO tasks (title, status) VALUES ('Deploy v2', 'pending') RETURNING id, title, status, created_at`
5. **PostgreSQL** inserts the row and returns the new record to Flask
6. **Flask** wraps the result in JSON and sends the HTTP response back through nginx
7. **nginx** forwards the response to the client
8. **Client** receives: `{"task": {"id": 7, "title": "Deploy v2", "status": "pending", "created_at": "2025-01-20T14:30:00"}}`

### Why Separate Tiers?

You could run everything in one process — Flask could serve HTTP directly and embed a SQLite database. Many tutorials do exactly this. But separation gives you:

| Benefit | Explanation |
|---------|------------|
| **Independent scaling** | If the API is the bottleneck, run more Flask instances behind nginx. If the database is the bottleneck, move it to a bigger server. |
| **Independent deployment** | Update the API without touching the database. Update nginx config without restarting Flask. |
| **Security boundaries** | nginx faces the internet. Flask only accepts connections from localhost. PostgreSQL only accepts connections from Flask. Attack surface shrinks at each layer. |
| **Technology independence** | Replace Flask with Go or Node. Replace nginx with HAProxy. Replace PostgreSQL with MariaDB. Each tier can change without affecting the others. |
| **Operational clarity** | When something breaks, you know which tier to investigate. |

In Weeks 16-17, you'll containerize this entire three-tier stack with Docker and Docker Compose — each tier in its own container, connected by a Docker network.

---

## 13.15 Monitoring and Troubleshooting

When databases misbehave, you need to know where to look.

### PostgreSQL Monitoring

**Check connections:**

```sql
-- Who's connected right now?
SELECT pid, usename, datname, client_addr, state, query
FROM pg_stat_activity
WHERE state != 'idle';
```

**Check database sizes:**

```sql
-- Size of each database
SELECT datname, pg_size_pretty(pg_database_size(datname))
FROM pg_database
ORDER BY pg_database_size(datname) DESC;
```

**Check table sizes:**

```sql
-- Connect to the database first, then:
SELECT tablename,
       pg_size_pretty(pg_total_relation_size(tablename::regclass)) AS total_size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(tablename::regclass) DESC;
```

**Check for slow queries:**

```sql
-- Enable query logging in postgresql.conf
-- log_min_duration_statement = 1000   (logs queries taking > 1 second)
```

After changing this, reload:

```bash
sudo systemctl reload postgresql
```

Then check the logs:

```bash
sudo journalctl -u postgresql -f
```

### MariaDB Monitoring

**Check connections:**

```sql
SHOW PROCESSLIST;
```

**Check database sizes:**

```sql
SELECT table_schema AS 'Database',
       ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.tables
GROUP BY table_schema
ORDER BY SUM(data_length + index_length) DESC;
```

**Check status:**

```sql
SHOW STATUS LIKE 'Threads_connected';
SHOW STATUS LIKE 'Slow_queries';
SHOW VARIABLES LIKE 'slow_query_log';
```

**Enable slow query log:**

```ini
# In /etc/my.cnf under [mysqld]
slow_query_log = 1
slow_query_log_file = /var/log/mariadb/slow-query.log
long_query_time = 1
```

### Common Troubleshooting

| Problem | Check | Fix |
|---------|-------|-----|
| Can't connect | `systemctl status postgresql` | Start/restart the service |
| "Connection refused" | `listen_addresses` in postgresql.conf | Set to `'*'` or the right IP |
| "No pg_hba.conf entry" | pg_hba.conf rules | Add appropriate host/user/method line |
| "Password authentication failed" | User exists? Password correct? | Reset with `ALTER ROLE taskapp PASSWORD 'new'` |
| "Permission denied for table" | GRANT statements | `GRANT SELECT, INSERT, ... ON tablename TO user` |
| "Too many connections" | `max_connections` | Increase in config or close idle connections |
| Slow queries | Indexes, EXPLAIN ANALYZE | Add indexes on filtered/joined columns |

**The EXPLAIN command** shows how the database plans to execute a query — invaluable for diagnosing slow queries:

```sql
EXPLAIN ANALYZE SELECT * FROM tasks WHERE status = 'pending';
```

```text
                                            QUERY PLAN
--------------------------------------------------------------------------------------------------
 Seq Scan on tasks  (cost=0.00..1.05 rows=3 width=136) (actual time=0.012..0.014 rows=3 loops=1)
   Filter: ((status)::text = 'pending'::text)
 Planning Time: 0.080 ms
 Execution Time: 0.032 ms
```

"Seq Scan" means a full table scan — acceptable for small tables, but a sign you need an index on larger ones. After adding an index, the plan changes to "Index Scan" or "Bitmap Index Scan."

### Service Health Checks

In Week 12, the Flask API had a `/healthz` endpoint that returned `{"status": "healthy"}`. Now that we have a database, a proper health check should verify the database connection too:

```python
@app.route("/healthz")
def health():
    conn = get_db_connection()
    if conn is None:
        return jsonify({"status": "unhealthy", "reason": "database unreachable"}), 503
    try:
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.close()
        conn.close()
        return jsonify({"status": "healthy"}), 200
    except Exception as e:
        return jsonify({"status": "unhealthy", "reason": str(e)}), 503
```

This pattern — checking real dependencies in health endpoints — is standard practice. Load balancers and container orchestrators use these health checks to decide whether to send traffic to an instance. If the database is down, the API correctly reports itself as unhealthy.

---

## What's Next

This week gave you two production-grade databases, the SQL to operate them, and the architecture to connect them to an application. The three-tier application you built in Lab 13.2 is the foundation for everything ahead:

- **Week 14** focuses on security hardening — you'll secure these database connections with TLS, restrict network access with firewalls, and audit user permissions
- **Week 15** introduces containers — the concept that will transform how you deploy applications
- **In Weeks 16-17**, you'll write a Dockerfile for the Flask API, a `docker-compose.yml` that spins up all three tiers (nginx, Flask, PostgreSQL) with a single command, and automated backup jobs inside containers

The Flask API you wrote today — with its CRUD endpoints, database connection, and health check — is the same application you'll containerize. Every environment variable, every endpoint, every database query carries forward. That's intentional. In the real world, you don't rewrite applications for each deployment model. You adapt the infrastructure around them.

---

## Labs

Complete the labs in the [labs/](labs/) directory:

- **[Lab 13.1: Database Server Setup](labs/lab_01_database_server_setup.md)** — Install PostgreSQL on Ubuntu and MariaDB on Rocky, create databases and users, practice SQL, back up and restore
- **[Lab 13.2: Three-Tier Application](labs/lab_02_three_tier_app.md)** — Build the full three-tier app: PostgreSQL + Flask API + nginx reverse proxy with CRUD endpoints

---

## Checklist

Before moving to Week 14, confirm you can:

- [ ] Install and start PostgreSQL on Ubuntu and MariaDB on Rocky
- [ ] Connect to each database with the command-line client (psql, mariadb)
- [ ] Create databases, tables, and indexes with SQL
- [ ] Insert, query, update, and delete data
- [ ] Write basic JOIN queries across two tables
- [ ] Create database users with limited permissions (principle of least privilege)
- [ ] Configure pg_hba.conf for remote PostgreSQL access
- [ ] Back up a database with pg_dump or mysqldump and restore it
- [ ] Explain the three-tier architecture and how requests flow through it
- [ ] Connect a Python application to PostgreSQL using psycopg2
- [ ] Test API endpoints with curl and verify data persists in the database

---

[← Previous Week](../week-12/README.md) · [Next Week →](../week-14/README.md)
