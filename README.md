# Database (PostgreSQL)

PostgreSQL database service for the Kubernetes-based e-commerce microservices platform.

This repository provides:

- PostgreSQL configuration and initialization
- Schema + seed setup
- Kubernetes manifests for **dev / staging / prod**
- Jenkins multibranch CI/CD pipeline
- Infrastructure validation integrated into CI/CD
- Schema smoke testing
- Persistent storage (PVC) verification
- Docker-based local development environment
- Terraform-integrated infrastructure outputs
- Security scanning via Docker Scout

---

# Architecture Context

The database service is part of a Kubernetes-deployed microservices architecture:

- **product-service** — Product API (stateless)
- **order-service** — Order API (stateless)
- **ecommerce-frontend** — React frontend served by Nginx
- **database** — PostgreSQL (stateful, this repository)

All services run in **environment-isolated Kubernetes namespaces**:

- dev
- staging
- prod

Infrastructure provisioning (cluster setup, ingress controller, environment configuration) is managed using **Terraform**.

Application deployment, testing, and validation are executed through **Jenkins CI/CD pipelines**.

---

# Release

Current release: **2.3.0**

Versioning follows **Semantic Versioning (SemVer)**:

MAJOR.MINOR.PATCH

- **MAJOR** — breaking schema changes
- **MINOR** — backward-compatible schema additions
- **PATCH** — fixes, seed updates, or non-breaking improvements

Production releases are triggered through **Git tags** (example: `v2.0.0`).

---

# Repository Structure

```
k8s/
  database/
    base/
      deployment.yaml
      service.yaml
      pvc.yaml
      configmap.yaml
      secret.yaml
      smoke-job.yaml
      pvc-write-job.yaml
      pvc-read-job.yaml
      kustomization.yaml

    overlays/
      dev/
      staging/
      prod/

deploy/
  docker/
    docker-compose.yml
    .env.example

schema/
  init.sql

tests/
  db-integration.sh
```

Kustomize overlays provide **environment-specific configuration** while sharing a common base manifest set.

---

# Service Design

## Internal Database Service

PostgreSQL is **not exposed via Kubernetes Ingress**.

Instead, it is accessible only within the Kubernetes cluster using an internal service.

Service type:

```
ClusterIP
```

Port:

```
5432
```

Internal DNS examples:

```
postgres.dev.svc.cluster.local
postgres.staging.svc.cluster.local
postgres.prod.svc.cluster.local
```

This ensures the database **remains private and inaccessible from the public network**.

---

# Deployment Strategy

The database is deployed as a **stateful Kubernetes workload**.

Configuration:

```
replicas: 1
strategy: Recreate
```

The **Recreate strategy** prevents multiple PostgreSQL instances from accessing the same persistent volume simultaneously.

Health checks use:

```
pg_isready
```

for:

- readinessProbe
- livenessProbe

---

# Persistent Storage

Each environment has its own **PersistentVolumeClaim (PVC)**.

| Environment | Storage |
|------------|--------|
| dev | 1Gi |
| staging | 2Gi |
| prod | 5Gi |

PVC configuration:

```
name: postgres-data
accessMode: ReadWriteOnce
storageClass: standard
```

Persistent volumes guarantee database data survives:

- pod restarts
- node rescheduling
- deployment rollouts

---

# CI/CD Pipeline (Jenkins)

This repository uses a **Jenkins Multibranch Pipeline** integrated with the system’s Git branching strategy.

## Branch Strategy

| Branch | Behavior |
|------|------|
| feature/* | Validation only |
| develop | Deploy to **dev** |
| release/* | Validation only |
| main | Deploy to **staging** |
| Git tag | Deploy to **prod** (manual approval) |

---

# Infrastructure Testing & Validation

Infrastructure validation is automatically executed during CI/CD to ensure Kubernetes manifests and deployment configurations are correct before deployment.

Validation includes:

1. **Kustomize compilation**
2. **Kubernetes client-side dry-run validation**
3. **Database deployment verification**
4. **Persistent storage validation**

Example validation commands:

```
kubectl kustomize <overlay>
kubectl apply --dry-run=client
```

This prevents invalid infrastructure configurations from reaching the Kubernetes cluster.

---

# Database Validation

## 1. Schema Smoke Test

A Kubernetes **Job** validates database schema integrity after deployment.

Checks include:

- required tables exist
- required columns exist
- foreign key relationships are present
- seed data is loaded

If validation fails, the pipeline **fails immediately**.

---

## 2. PVC Persistence Verification

CI/CD performs an automated persistence test.

### Step 1 — Write Marker

A CI-generated marker value is written to the database.

### Step 2 — Restart Database

```
kubectl rollout restart deployment/postgres
```

### Step 3 — Read Marker

A verification job checks whether the marker still exists.

Successful verification proves that data **survives pod restarts**, confirming persistent storage works correctly.

---

# Terraform Infrastructure Integration

Infrastructure provisioning is handled in a **separate Terraform repository**.

Terraform provisions:

- Kubernetes cluster configuration
- ingress-nginx controller
- namespace isolation for environments
- cluster infrastructure outputs used by CI/CD

Terraform pipelines perform infrastructure validation using:

```
terraform fmt -check
terraform validate
terraform plan
```

Terraform outputs are exported as:

```
infra-outputs.json
infra-outputs-dev.json
infra-outputs-staging.json
infra-outputs-prod.json
```

These outputs include:

- Kubernetes context
- ingress controller namespace
- ingress service name
- cluster access configuration

Application pipelines retrieve these artifacts and load them using:

```
deploy/ci/load-infra-outputs.sh
```

This ensures services deploy against the **correct infrastructure environment** created by Terraform.

Note:

Terraform manages **platform infrastructure**, while the database itself is deployed via **Kubernetes manifests in this repository**.

---

# Local Development (Docker Compose)

Docker Compose is provided for **local development and integration testing**.

## Start Database

```
cp deploy/docker/.env.example deploy/docker/.env

docker compose -f deploy/docker/docker-compose.yml   --env-file deploy/docker/.env   up -d
```

## Reset Database

```
docker compose -f deploy/docker/docker-compose.yml   --env-file deploy/docker/.env   down -v

docker compose -f deploy/docker/docker-compose.yml   --env-file deploy/docker/.env   up -d
```

---

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