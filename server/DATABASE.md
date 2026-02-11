# FinWise Database Documentation

## Overview

FinWise uses **PostgreSQL** with **SQLAlchemy 2.0** (async) for data persistence and aggregated analytics on the server side.

**Important:** The app follows an **Offline-First** architecture:
- Flutter app stores all data locally in **Hive**
- Server database is optional and used for:
  - ML model training and inference
  - Aggregated analytics
  - Multi-device synchronization
  - Long-term data storage

## Database Schema

### Tables

#### `users`
Stores user profiles and settings.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `username` | String(100) | Display name |
| `email` | String(255) | Email (unique, optional) |
| `hashed_password` | String(255) | Bcrypt password hash (optional for offline-first) |
| `currency` | String(3) | ISO 4217 currency code (default: RUB) |
| `timezone` | String(50) | Timezone (default: Europe/Moscow) |
| `theme` | String(10) | UI theme: light or dark |
| `created_at` | DateTime | Account creation timestamp |
| `updated_at` | DateTime | Last update timestamp |
| `last_sync_at` | DateTime | Last sync with client |
| `is_active` | Boolean | Account status |

#### `categories`
Transaction categories (both default and user-defined).

| Column | Type | Description |
|--------|------|-------------|
| `id` | Integer | Primary key (auto-increment) |
| `user_id` | UUID | Foreign key to users (nullable for default categories) |
| `name` | String(100) | Category name (e.g., "Продукты", "Транспорт") |
| `color` | String(7) | Hex color code (e.g., #F97316) |
| `icon` | String(50) | Icon name/code |
| `is_default` | Boolean | True for pre-installed categories |

**Default Categories:** 20 pre-installed categories (see `scripts/seed_categories.py`)

#### `transactions`
Financial transactions (income/expenses).

| Column | Type | Description |
|--------|------|-------------|
| `id` | Integer | Primary key (auto-increment) |
| `user_id` | UUID | Foreign key to users |
| `category_id` | Integer | Foreign key to categories (nullable) |
| `amount` | Float | Transaction amount (positive = income, negative = expense) |
| `description` | Text | Transaction description |
| `date` | DateTime | Transaction date/time |
| `receipt_data` | JSONB | Receipt data (QR, items, retailer) - nullable |
| `ml_category` | String(100) | ML-predicted category (nullable) |
| `ml_confidence` | Float | ML prediction confidence (0-1) |
| `is_anomaly` | Boolean | Anomaly detection flag |
| `device_id` | String(100) | Device ID for multi-device sync |
| `created_at` | DateTime | Record creation timestamp |
| `updated_at` | DateTime | Last update timestamp |
| `version` | Integer | Version for conflict resolution |

**Indexes:** `user_id`, `category_id`, `date`

#### `budgets`
Monthly budget settings.

| Column | Type | Description |
|--------|------|-------------|
| `id` | Integer | Primary key (auto-increment) |
| `user_id` | UUID | Foreign key to users |
| `monthly_amount` | Float | Monthly budget amount |
| `period_start` | DateTime | Budget period start date |
| `period_end` | DateTime | Budget period end date (nullable) |
| `created_at` | DateTime | Record creation timestamp |
| `updated_at` | DateTime | Last update timestamp |

**Indexes:** `user_id`, `period_start`

## Setup Instructions

### 1. Install PostgreSQL

Ensure PostgreSQL 14+ is installed and running:

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install postgresql postgresql-contrib

# macOS
brew install postgresql
brew services start postgresql

# Windows
# Download from https://www.postgresql.org/download/windows/
```

### 2. Create Database

```bash
# Connect to PostgreSQL
sudo -u postgres psql

# Create database and user
CREATE DATABASE finwise;
CREATE USER finwise WITH PASSWORD 'finwise';
GRANT ALL PRIVILEGES ON DATABASE finwise TO finwise;
\q
```

### 3. Configure Environment

Copy `.env.example` to `.env` and update:

```env
DATABASE_URL=postgresql://finwise:finwise@localhost:5432/finwise
```

### 4. Run Migrations

```bash
cd server

# Apply all migrations
alembic upgrade head

# Check current revision
alembic current

# View migration history
alembic history --verbose
```

### 5. Seed Default Categories

```bash
cd server
python scripts/seed_categories.py
```

## Development Workflow

### Creating a New Migration

```bash
# Auto-generate migration based on model changes
alembic revision --autogenerate -m "add user avatar field"

# Review generated migration in alembic/versions/
# Edit if needed, then apply:
alembic upgrade head
```

### Rolling Back

```bash
# Rollback one migration
alembic downgrade -1

# Rollback to specific revision
alembic downgrade <revision_id>

# Rollback all
alembic downgrade base
```

### Database Reset (Development)

```bash
# WARNING: This deletes all data!
alembic downgrade base
alembic upgrade head
python scripts/seed_categories.py
```

## Usage in Code

### Getting Database Session

```python
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.db import get_db

@app.get("/users")
async def get_users(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User))
    users = result.scalars().all()
    return users
```

### Querying Data

```python
from sqlalchemy import select
from app.models import User, Transaction

# Get user by ID
user = await db.get(User, user_id)

# Query with filters
result = await db.execute(
    select(Transaction)
    .where(Transaction.user_id == user_id)
    .where(Transaction.date >= start_date)
    .order_by(Transaction.date.desc())
)
transactions = result.scalars().all()

# Aggregation
from sqlalchemy import func
result = await db.execute(
    select(func.sum(Transaction.amount))
    .where(Transaction.user_id == user_id)
    .where(Transaction.amount < 0)
)
total_expenses = result.scalar()
```

### Creating Records

```python
from app.models import Transaction

# Create new transaction
transaction = Transaction(
    user_id=user_id,
    category_id=1,
    amount=-1500.50,
    description="Groceries",
    date=datetime.now()
)
db.add(transaction)
await db.commit()
await db.refresh(transaction)
```

### Updating Records

```python
transaction = await db.get(Transaction, transaction_id)
transaction.amount = -1600.00
transaction.description = "Updated: Groceries"
await db.commit()
```

### Deleting Records

```python
transaction = await db.get(Transaction, transaction_id)
await db.delete(transaction)
await db.commit()
```

## Best Practices

### 1. Use Async Everywhere

```python
# ✅ Good
async def get_user(user_id: UUID, db: AsyncSession = Depends(get_db)):
    user = await db.get(User, user_id)
    return user

# ❌ Bad - blocking call
def get_user_sync(user_id: UUID):
    # Don't use synchronous SQLAlchemy with FastAPI
    pass
```

### 2. Always Use Indexes

Add indexes for:
- Foreign keys
- Date fields (for time-based queries)
- Fields used in WHERE clauses frequently

```python
# In model
date = Column(DateTime, index=True)
```

### 3. Handle Cascading Deletes

```python
# When deleting a user, also delete their transactions
user_id = Column(UUID, ForeignKey("users.id", ondelete="CASCADE"))
```

### 4. Use JSONB for Flexible Data

```python
# Store receipt data as JSONB
receipt_data = Column(JSONB, nullable=True)

# Query JSONB fields
result = await db.execute(
    select(Transaction)
    .where(Transaction.receipt_data['retailer_name'].astext == 'Пятёрочка')
)
```

### 5. Optimize Queries

```python
# ✅ Good - load related data in one query
from sqlalchemy.orm import selectinload

result = await db.execute(
    select(User)
    .options(selectinload(User.transactions))
    .where(User.id == user_id)
)
user = result.scalar_one()

# ❌ Bad - N+1 query problem
user = await db.get(User, user_id)
for transaction in user.transactions:  # Triggers separate query
    print(transaction.amount)
```

## Connection Pool Configuration

Current settings (optimized for 2 CPU, 2 GB RAM server):

```python
# In app/db/session.py
engine = create_async_engine(
    DATABASE_URL,
    pool_size=10,        # Max 10 connections
    max_overflow=20,     # Allow 20 extra connections temporarily
    pool_pre_ping=True,  # Check connection health before use
)
```

## Monitoring

### Check Connection Pool

```python
from app.db.session import engine

# In endpoint or script
print(f"Pool size: {engine.pool.size()}")
print(f"Checked out: {engine.pool.checkedout()}")
```

### PostgreSQL Queries

```sql
-- Active connections
SELECT * FROM pg_stat_activity WHERE datname = 'finwise';

-- Database size
SELECT pg_size_pretty(pg_database_size('finwise'));

-- Table sizes
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

## Backup & Restore

### Backup

```bash
# Full backup
pg_dump -U finwise finwise > finwise_backup.sql

# Backup to custom format (compressed)
pg_dump -U finwise -Fc finwise > finwise_backup.dump
```

### Restore

```bash
# From SQL file
psql -U finwise finwise < finwise_backup.sql

# From custom format
pg_restore -U finwise -d finwise finwise_backup.dump
```

### Automated Backups (Production)

Add to crontab:

```bash
# Daily backup at 3 AM
0 3 * * * pg_dump -U finwise -Fc finwise > /backups/finwise_$(date +\%Y\%m\%d).dump

# Keep only last 7 days
0 4 * * * find /backups -name "finwise_*.dump" -mtime +7 -delete
```

## Troubleshooting

### Connection Refused

```bash
# Check PostgreSQL is running
sudo systemctl status postgresql

# Start if stopped
sudo systemctl start postgresql

# Check listening ports
sudo netstat -plnt | grep postgres
```

### Permission Denied

```bash
# Grant privileges
sudo -u postgres psql
GRANT ALL PRIVILEGES ON DATABASE finwise TO finwise;
GRANT ALL ON ALL TABLES IN SCHEMA public TO finwise;
```

### Migration Conflicts

```bash
# Check current state
alembic current
alembic history

# Stamp to specific revision (without running migration)
alembic stamp <revision_id>
```

### Slow Queries

```sql
-- Enable query logging in postgresql.conf
log_min_duration_statement = 1000  # Log queries > 1 second

-- Analyze query performance
EXPLAIN ANALYZE SELECT * FROM transactions WHERE user_id = '...';
```

## Related Files

- Models: `app/models/*.py`
- Session: `app/db/session.py`
- Base: `app/db/base.py`
- Migrations: `alembic/versions/*.py`
- Seed script: `scripts/seed_categories.py`
- Config: `app/config.py`
- Alembic config: `alembic.ini`
