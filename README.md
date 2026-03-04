# Database (PostgreSQL)

PostgreSQL database service for the Kubernetes-based e-commerce
microservices system.

This repository provides:

-   PostgreSQL configuration
-   Schema + seed initialization
-   Kubernetes manifests (dev / staging / prod)
-   Jenkins multibranch CI/CD integration
-   Persistent storage validation (PVC proof)
-   Security scanning via Docker Scout
-   Terraform-based infrastructure integration

------------------------------------------------------------------------

# Architecture Context

This database service is part of a Kubernetes‑deployed microservices
architecture:

-   **product-service** --- Product API (stateless, RollingUpdate)
-   **order-service** --- Order API (stateless, RollingUpdate)
-   **ecommerce-frontend** --- React frontend served by Nginx
-   **database** --- PostgreSQL (stateful, this repository)

All services run inside **environment‑isolated Kubernetes namespaces**:

-   dev
-   staging
-   prod

Infrastructure for the cluster, ingress controller, and supporting
resources is provisioned using **Terraform**.

Application deployment and validation is handled by **Jenkins
pipelines**.

------------------------------------------------------------------------

# Release

Current release: 2.1.0

Versioning follows **Semantic Versioning (SemVer)**:

MAJOR.MINOR.PATCH

-   MAJOR --- breaking schema changes
-   MINOR --- backward‑compatible schema additions
-   PATCH --- fixes, seed updates, non‑breaking improvements

Production releases are triggered via **Git tags** (example: `v2.0.0`).

------------------------------------------------------------------------

# Kubernetes Architecture

## Folder Structure

k8s/database/ base/ deployment.yaml service.yaml pvc.yaml configmap.yaml
secret.yaml smoke-job.yaml pvc-write-job.yaml pvc-read-job.yaml
kustomization.yaml overlays/ dev/ staging/ prod/

Kustomize overlays provide **environment‑specific configuration** while
sharing a common base manifest set.

------------------------------------------------------------------------

# Service Design

## No Ingress

PostgreSQL is not an HTTP service and therefore **does not use
Kubernetes Ingress**.

The database is accessible **only within the cluster network**.

## Internal Access

Service type: **ClusterIP**

Port: **5432**

Internal DNS access examples:

postgres.dev.svc.cluster.local\
postgres.staging.svc.cluster.local\
postgres.prod.svc.cluster.local

This design ensures the database **remains private and inaccessible from
the public network**.

------------------------------------------------------------------------

# Deployment Strategy

Database deployments use:

replicas: 1\
strategy: Recreate

Recreate strategy is used because PostgreSQL is **stateful** and must
not run multiple instances against the same PVC.

Health probes use **pg_isready** for both:

-   readinessProbe
-   livenessProbe

------------------------------------------------------------------------

# Persistent Storage

Each environment provisions its own **PersistentVolumeClaim**.

  Environment   Storage
  ------------- ---------
  dev           1Gi
  staging       2Gi
  prod          5Gi

PVC configuration:

name: postgres-data\
accessMode: ReadWriteOnce\
storageClass: standard

PVCs guarantee database data persists across:

-   pod restarts
-   rolling deployments
-   node rescheduling

------------------------------------------------------------------------

# CI/CD Pipeline (Jenkins)

This repository uses a **Jenkins Multibranch Pipeline**.

## Branch Strategy

  Branch       Behavior
  ------------ ----------------------------------
  feature/\*   Validation only
  develop      Deploy to dev
  release/\*   Validation only
  main         Deploy to staging
  Git tag      Deploy to prod (manual approval)

------------------------------------------------------------------------

## Pipeline Stages

1.  Kustomize compile validation
2.  Apply Kubernetes overlay
3.  Wait for PVC binding
4.  Wait for deployment rollout
5.  Schema smoke test (Kubernetes Job)
6.  PVC persistence validation
7.  Debug snapshot collection

------------------------------------------------------------------------

# Database Validation

## 1) Schema Smoke Test

A Kubernetes **Job** validates database correctness.

Validation checks:

-   Tables exist
-   Required columns exist
-   Foreign key relationships exist
-   Seed data present

If validation fails, the pipeline **fails immediately**.

------------------------------------------------------------------------

## 2) PVC Persistence Proof

Persistence is verified during CI using a three‑step test.

Step 1 --- Write Marker\
A CI‑generated marker is written to the database.

Step 2 --- Restart Database

kubectl rollout restart deployment/postgres

Step 3 --- Read Marker

A second job verifies the marker still exists.

If successful, this proves **data survives pod restarts**, confirming
real persistent storage.

------------------------------------------------------------------------

# Terraform Infrastructure Integration

Infrastructure provisioning is managed in a **separate Terraform
repository**.

Terraform provisions:

-   Kubernetes cluster configuration
-   ingress-nginx controller
-   development infrastructure resources
-   environment workspace separation
-   infrastructure outputs for CI/CD pipelines

Terraform outputs are exported to:

infra-outputs.json\
infra-outputs-dev.json\
infra-outputs-staging.json\
infra-outputs-prod.json

These outputs include:

-   Kubernetes context
-   ingress controller namespace
-   ingress service name
-   cluster access details

Jenkins pipelines retrieve these artifacts and load them using:

deploy/ci/load-infra-outputs.sh

This ensures service pipelines deploy against the **correct environment
infrastructure** created by Terraform.

Note:

The database itself is deployed via Jenkins using Kubernetes manifests,
while Terraform manages the **underlying platform infrastructure**.

------------------------------------------------------------------------

# Local Development (Docker Compose)

Docker Compose is retained for **local development only**.

## Start Database

cp deploy/docker/.env.example deploy/docker/.env

docker compose -f deploy/docker/docker-compose.yml --env-file
deploy/docker/.env up -d

## Reset Database

docker compose -f deploy/docker/docker-compose.yml --env-file
deploy/docker/.env down -v

docker compose -f deploy/docker/docker-compose.yml --env-file
deploy/docker/.env up -d

------------------------------------------------------------------------

# Security Scanning

The official PostgreSQL image:

postgres:16-alpine

is scanned using **Docker Scout**.

Policy: **notify-only**

Vulnerabilities inherited from upstream system libraries are monitored
and addressed through:

-   periodic base image updates
-   upstream patch monitoring

Official images are preferred for:

-   stability
-   maintenance reliability
-   supply chain trust

------------------------------------------------------------------------

# Current Status

The database service now includes:

-   Kubernetes stateful deployment
-   Environment‑isolated namespaces
-   Persistent volume claims per environment
-   Automated schema validation
-   Verified PVC persistence testing
-   Jenkins CI/CD automation
-   Terraform‑integrated infrastructure provisioning

This repository represents a **production‑style Kubernetes database
deployment with CI‑driven validation and persistent storage
verification**.
