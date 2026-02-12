# Database (PostgreSQL)

PostgreSQL database for the e-commerce microservices project. This repository provides a standalone database setup with initialization scripts (schema + seed) so other services can connect via environment variables.

## Release
- Current release: 1.1.0

## What’s in this repo
- PostgreSQL container configuration (Docker Compose)
- Database initialization scripts (schema/seed) in `schema/`

## Prerequisites
- Docker + Docker Compose (Docker Desktop)

## Quick Start (Docker Compose)

### 1) Create your local environment file
From the repo root:
```bash
cp deploy/docker/.env.example deploy/docker/.env
```
Edit deploy/docker/.env if you want different values.

### 2) Start the database
From the repo root:

```bash
docker compose -f deploy/docker/docker-compose.yml --env-file deploy/docker/.env up -d
docker ps
```

### 3) Verify the database is running
```bash
docker exec -it <container-name> psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "\dt"
```

## Initialization Scripts
SQL files are located in schema/ (e.g. schema/init.sql).

These scripts run automatically only on first startup (i.e., when the database volume is empty).
If you change the SQL and want it to run again, reset the volume (see below).

## Reset Database (re-run init scripts)
From the repo root:

```bash
docker compose -f deploy/docker/docker-compose.yml --env-file deploy/docker/.env down -v
docker compose -f deploy/docker/docker-compose.yml --env-file deploy/docker/.env up -d
```

## Configuration
Environment variables are defined in deploy/docker/.env:
- POSTGRES_USER
- POSTGRES_PASSWORD
- POSTGRES_DB
- POSTGRES_PORT (host port)

Host (from your laptop): localhost
Port: value of POSTGRES_PORT (default 5432)

## Security Scanning (Docker Scout)

This repository uses the official PostgreSQL image (`postgres:16-alpine`). Since we do not maintain the upstream image, vulnerabilities may be reported by scanners even when using an official tag.

We use **Docker Scout** to continuously assess the image for known CVEs and to make informed decisions about image versions.

### Run a scan
From the repo root:
```bash
chmod +x scripts/security-docker-scout-scan.sh
./scripts/security-docker-scout-scan.sh
```

### Policy / Rationale
We prefer official images for stability and supply-chain provenance.
We scan multiple compatible tags and select the lowest-risk option available at the time of implementation.