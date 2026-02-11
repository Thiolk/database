# Database (PostgreSQL)

PostgreSQL database for the e-commerce microservices project. This repository provides a standalone database setup with initialization scripts (schema + seed) so other services can connect via environment variables.

## What’s in this repo
- PostgreSQL container configuration (Docker Compose)
- Database initialization scripts (schema/seed)

## Prerequisites
- Docker + Docker Compose

---

## Quick Start (Docker Compose)

### 1) Start the database
From the repo root:
```bash
cd deploy/docker
docker compose up -d
docker ps
docker exec -it <db_container> psql -U app -d appdb -c "\dt"
```

## Initialization Scripts
SQL files are in schema
These scripts run automatically only on first startup (i.e., when the database volume is empty).

## Reset Database
cd deploy/docker
docker compose down -v
docker compose up -d

## Configuration
Environment variables used by PostgreSQL are set in docker-compose.yml
- POSTGRES_USER
- POSTGRES_PASSWORD
- POSTGRES_DB
- Host (from your laptop): localhost
- Port: 5432

Example connection string:
postgresql://app:app@localhost:5432/appdb