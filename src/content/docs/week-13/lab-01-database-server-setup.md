---
title: "Lab 13.1: Database Server Setup"
sidebar:
  order: 1
---


> **Objective:** Install PostgreSQL on Ubuntu and MariaDB on Rocky. On each: secure the installation, create a database and application user, create tables, insert and query data, configure remote access, and back up/restore.
>
> **Concepts practiced:** PostgreSQL installation and configuration, MariaDB installation, SQL (CREATE, INSERT, SELECT, JOIN), pg_hba.conf, user permissions, pg_dump, mysqldump
>
> **Time estimate:** 45 minutes
>
> **VM(s) needed:** Both Ubuntu and Rocky

---

## Part 1: PostgreSQL on Ubuntu

### Step 1: Install PostgreSQL

```bash
sudo apt update
sudo apt install -y postgresql postgresql-contrib
```

Verify the service is running:

```bash
sudo systemctl status postgresql
```

Confirm the version:

```bash
psql --version
```

### Step 2: Connect as the postgres Superuser

```bash
sudo -u postgres psql
```

You should see the `postgres=#` prompt. Explore the default state:

```sql
-- List databases
\l

-- List users/roles
\du

-- Exit
\q
```

### Step 3: Create a Database and Application User

```bash
sudo -u postgres psql
```

```sql
-- Create the database
CREATE DATABASE shopdb;

-- Create an application user with a password
CREATE ROLE shopapp WITH LOGIN PASSWORD 'shop_pass_123';

-- Grant connect permission
GRANT CONNECT ON DATABASE shopdb TO shopapp;

-- Switch to the new database
\c shopdb

-- Grant schema and table permissions
GRANT USAGE ON SCHEMA public TO shopapp;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO shopapp;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO shopapp;

-- Apply to future tables as well
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO shopapp;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO shopapp;
```

### Step 4: Create Tables

Still connected to `shopdb` as the postgres superuser:

```sql
CREATE TABLE customers (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    email       VARCHAR(150) UNIQUE NOT NULL,
    created_at  TIMESTAMP DEFAULT NOW()
);

CREATE TABLE orders (
    id          SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(id),
    product     VARCHAR(200) NOT NULL,
    amount      DECIMAL(10,2) NOT NULL,
    status      VARCHAR(20) DEFAULT 'pending',
    created_at  TIMESTAMP DEFAULT NOW()
);
```

Verify the structure:

```sql
\dt
\d customers
\d orders
```

### Step 5: Insert Data

```sql
INSERT INTO customers (name, email) VALUES
    ('Alice Chen', 'alice@example.com'),
    ('Bob Kumar', 'bob@example.com'),
    ('Carol Diaz', 'carol@example.com');

INSERT INTO orders (customer_id, product, amount, status) VALUES
    (1, 'Linux Administration Book', 49.99, 'complete'),
    (1, 'Mechanical Keyboard', 129.00, 'shipped'),
    (2, 'USB-C Hub', 34.50, 'pending'),
    (2, '27-inch Monitor', 399.99, 'complete'),
    (3, 'Webcam HD', 79.95, 'pending');
```

### Step 6: Practice Queries

Try each of these and confirm you understand the output:

```sql
-- All customers
SELECT * FROM customers;

-- Orders over $50
SELECT * FROM orders WHERE amount > 50.00;

-- Count orders by status
SELECT status, COUNT(*) AS order_count FROM orders GROUP BY status;

-- Total revenue from completed orders
SELECT SUM(amount) AS total_revenue FROM orders WHERE status = 'complete';

-- JOIN: show customer names with their orders
SELECT c.name, o.product, o.amount, o.status
FROM orders o
INNER JOIN customers c ON o.customer_id = c.id
ORDER BY c.name, o.created_at;

-- LEFT JOIN: all customers, including those with no orders
-- (Currently all have orders — try adding a customer with no order to test)
INSERT INTO customers (name, email) VALUES ('Dave Park', 'dave@example.com');

SELECT c.name, COUNT(o.id) AS order_count
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
GROUP BY c.name
ORDER BY order_count DESC;
```

The last query should show Dave Park with 0 orders.

### Step 7: Test the Application User

Exit psql and reconnect as the `shopapp` user:

```bash
psql -h localhost -U shopapp -d shopdb
```

Enter the password `shop_pass_123`. Try:

```sql
-- This should work (SELECT is granted)
SELECT * FROM customers;

-- This should work (INSERT is granted)
INSERT INTO customers (name, email) VALUES ('Eve Foster', 'eve@example.com');

-- This should FAIL (CREATE TABLE is not granted)
CREATE TABLE test_table (id INTEGER);
```

You should see `ERROR: permission denied for schema public` on the CREATE TABLE. That's the principle of least privilege in action.

Exit with `\q`.

### Step 8: Configure Remote Access

Edit `pg_hba.conf` to allow your Rocky VM to connect (replace `192.168.1.0/24` with your actual subnet):

```bash
sudo nano /etc/postgresql/16/main/pg_hba.conf
```

Add this line before the existing rules:

```text
host    shopdb          shopapp         192.168.1.0/24          scram-sha-256
```

Update `postgresql.conf` to listen on all interfaces:

```bash
sudo nano /etc/postgresql/16/main/postgresql.conf
```

Find `listen_addresses` and change it:

```ini
listen_addresses = '*'
```

Restart PostgreSQL (listen_addresses requires restart, not just reload):

```bash
sudo systemctl restart postgresql
```

If you have UFW enabled (from earlier weeks), allow the port:

```bash
sudo ufw allow 5432/tcp
```

### Step 9: Back Up and Restore

Create a backup:

```bash
sudo -u postgres pg_dump shopdb > /tmp/shopdb_backup.sql
```

Verify the backup file contains SQL:

```bash
head -20 /tmp/shopdb_backup.sql
```

You should see `CREATE TABLE` statements and `INSERT` or `COPY` commands.

Now test the restore cycle — drop and recreate:

```bash
# Drop the database (make sure you're not connected to it)
sudo -u postgres dropdb shopdb

# Confirm it's gone
sudo -u postgres psql -c "\l"

# Recreate the empty database
sudo -u postgres createdb shopdb

# Restore from backup
sudo -u postgres psql shopdb < /tmp/shopdb_backup.sql

# Verify data is back
sudo -u postgres psql shopdb -c "SELECT COUNT(*) FROM customers;"
```

You should see the same number of customers as before the drop.

Re-grant permissions to shopapp on the restored database:

```bash
sudo -u postgres psql shopdb -c "GRANT USAGE ON SCHEMA public TO shopapp;"
sudo -u postgres psql shopdb -c "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO shopapp;"
sudo -u postgres psql shopdb -c "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO shopapp;"
```

---

## Part 2: MariaDB on Rocky

### Step 1: Install MariaDB

```bash
sudo dnf install -y mariadb-server mariadb
sudo systemctl enable --now mariadb
```

Verify:

```bash
sudo systemctl status mariadb
```

### Step 2: Secure the Installation

```bash
sudo mysql_secure_installation
```

Follow the prompts — answer `Y` to all questions. Set a root password you'll remember.

### Step 3: Connect and Create a Database

```bash
sudo mariadb
```

```sql
-- Create the database
CREATE DATABASE shopdb;

-- Create the application user
CREATE USER 'shopapp'@'localhost' IDENTIFIED BY 'shop_pass_123';

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON shopdb.* TO 'shopapp'@'localhost';
FLUSH PRIVILEGES;

-- Switch to the database
USE shopdb;
```

### Step 4: Create Tables

```sql
CREATE TABLE customers (
    id          INTEGER AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    email       VARCHAR(150) UNIQUE NOT NULL,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE orders (
    id          INTEGER AUTO_INCREMENT PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    product     VARCHAR(200) NOT NULL,
    amount      DECIMAL(10,2) NOT NULL,
    status      VARCHAR(20) DEFAULT 'pending',
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(id)
);
```

Verify:

```sql
SHOW TABLES;
DESCRIBE customers;
DESCRIBE orders;
```

### Step 5: Insert and Query Data

```sql
INSERT INTO customers (name, email) VALUES
    ('Alice Chen', 'alice@example.com'),
    ('Bob Kumar', 'bob@example.com'),
    ('Carol Diaz', 'carol@example.com');

INSERT INTO orders (customer_id, product, amount, status) VALUES
    (1, 'Linux Administration Book', 49.99, 'complete'),
    (1, 'Mechanical Keyboard', 129.00, 'shipped'),
    (2, 'USB-C Hub', 34.50, 'pending'),
    (2, '27-inch Monitor', 399.99, 'complete'),
    (3, 'Webcam HD', 79.95, 'pending');
```

Run the same queries as Part 1 to practice (the SQL is nearly identical — the only difference is MariaDB uses `EXIT;` instead of `\q`):

```sql
SELECT status, COUNT(*) AS order_count FROM orders GROUP BY status;

SELECT SUM(amount) AS total_revenue FROM orders WHERE status = 'complete';

SELECT c.name, o.product, o.amount
FROM orders o
INNER JOIN customers c ON o.customer_id = c.id
ORDER BY c.name;
```

### Step 6: Test the Application User

Exit and reconnect as `shopapp`:

```bash
mariadb -u shopapp -p shopdb
```

```sql
-- Should work
SELECT * FROM customers;

-- Should FAIL
CREATE TABLE test_table (id INTEGER);
```

You should see `ERROR 1142: CREATE command denied to user 'shopapp'@'localhost'`.

### Step 7: Back Up and Restore

```bash
# Back up
sudo mysqldump shopdb > /tmp/shopdb_backup.sql

# Verify contents
head -20 /tmp/shopdb_backup.sql

# Drop and restore
sudo mariadb -e "DROP DATABASE shopdb;"
sudo mariadb -e "CREATE DATABASE shopdb;"
sudo mariadb shopdb < /tmp/shopdb_backup.sql

# Verify
sudo mariadb shopdb -e "SELECT COUNT(*) FROM customers;"
```

---

## Part 3: Compare the Experience

Now that you've done the same task on both systems, answer these questions in your notes:

1. Which system was faster to get to a working state? Why?
2. How does PostgreSQL's peer authentication compare to MariaDB's `mysql_secure_installation` approach?
3. What happens when you try to INSERT invalid data (e.g., a string where an integer is expected)? Try it on both.
4. What was different about creating users and granting permissions?
5. Compare the backup file formats — open both `/tmp/shopdb_backup.sql` files and look at the structure.

These aren't trick questions. The point is to build intuition about both systems so you can work with whichever one you encounter in production.

---

## Verification Checklist

- [ ] PostgreSQL is installed and running on Ubuntu
- [ ] MariaDB is installed and running on Rocky
- [ ] Created `shopdb` database on both systems
- [ ] Created `shopapp` user with limited permissions on both
- [ ] Created `customers` and `orders` tables with proper data types
- [ ] Inserted sample data and ran SELECT, JOIN, GROUP BY queries
- [ ] Confirmed app user cannot CREATE TABLE (least privilege works)
- [ ] Configured pg_hba.conf for remote access on Ubuntu
- [ ] Backed up and restored the database on both systems
