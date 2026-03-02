
# Database (PostgreSQL)

PostgreSQL database service for the Kubernetes-based e-commerce microservices system.

This repository provides:

- PostgreSQL configuration
- Schema + seed initialization
- Kubernetes manifests (dev / staging / prod)
- Jenkins multibranch CI/CD integration
- Persistent storage validation (PVC proof)
- Security scanning via Docker Scout

---

## Architecture Context

This database service is part of a Kubernetes-deployed microservices architecture:

- product-service — Product API (stateless, RollingUpdate)
- order-service — Order API (stateless, RollingUpdate)
- ecommerce-frontend — React frontend via Nginx
- database — PostgreSQL (stateful, this repository)

All services are deployed into separate namespaces:

- dev
- staging
- prod

---

## Release

Current release: 2.1.0

Versioning follows Semantic Versioning (SemVer):

MAJOR.MINOR.PATCH

- MAJOR: breaking schema changes
- MINOR: backward-compatible schema additions
- PATCH: fixes, seed updates, non-breaking improvements

Production releases are triggered via Git tags (e.g., v2.0.0).

---

# Kubernetes Architecture

## Folder Structure

k8s/database/
  base/
    deployment.yaml
    service.yaml
    pvc.yaml
    configmap.yaml
    secret.yaml
    smoke-job.yaml
    pvc-write-job.yaml
    pvc-read-job.yaml
  overlays/
    dev/
    staging/
    prod/

---

## Service Design

### No Ingress

PostgreSQL is not HTTP-based and does not require external ingress routing.

### No NodePort

The database is internal-only and exposed via:

Service type: ClusterIP
Port: 5432

Accessed internally using:

postgres.<namespace>.svc.cluster.local

---

## Deployment Strategy

- Kubernetes Deployment
- replicas: 1
- strategy: Recreate
- Readiness & liveness probes via pg_isready

Recreate strategy is used because the database is stateful and single-instance.

---

## Persistent Storage

Each environment provisions its own PersistentVolumeClaim:

- dev → 1Gi
- staging → 2Gi
- prod → 5Gi

PVC Name: postgres-data  
AccessMode: ReadWriteOnce  
StorageClass: standard

---

# CI/CD (Jenkins Multibranch Pipeline)

Branch Strategy:

- feature/* → Validate only
- develop → Deploy to dev
- release/* → Validation only
- main → Deploy to staging
- Git tag → Deploy to prod (manual approval required)

Pipeline stages:

1. Kustomize compile validation
2. Apply overlay
3. Wait for PVC bound
4. Wait for deployment rollout
5. Schema smoke test (Kubernetes Job)
6. PVC persistence proof (write → restart → read)
7. Post-build debug snapshots

---

# Database Validation

## 1) Schema Smoke Test

Kubernetes Job validates:

- Tables exist
- Required columns exist
- Foreign keys exist
- Seed data present

Fails pipeline if validation fails.

---

## 2) PVC Persistence Proof

Jenkins performs:

1. Insert unique build marker row
2. Restart postgres deployment
3. Verify marker still exists

This proves real persistence across pod restarts.

---

# Local Development (Docker Compose)

Docker Compose is retained for local development only.

Quick start:

cp deploy/docker/.env.example deploy/docker/.env
docker compose -f deploy/docker/docker-compose.yml --env-file deploy/docker/.env up -d

Reset database:

docker compose -f deploy/docker/docker-compose.yml --env-file deploy/docker/.env down -v
docker compose -f deploy/docker/docker-compose.yml --env-file deploy/docker/.env up -d

---

# Security Scanning

The official PostgreSQL image (postgres:16-alpine) is scanned via Docker Scout (notify-only).

We prefer official images for stability and supply-chain provenance. We scan multiple compatible tags and select the lowest-risk option
available at the time of implementation. Security findings are reviewed regularly, and image versions are upgraded when stable upstream patches
are released.

---

# Current Status

- ClusterIP internal-only database
- PVC bound in dev/staging/prod
- Schema validation working
- Persistence validated via CI
- Jenkins environment-aware deployment functioning

---

This repository now reflects a production-style Kubernetes database deployment with verified persistence and CI-driven validation.
