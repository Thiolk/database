pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  environment {
    COMPOSE_FILE = "deploy/docker/docker-compose.yml"
    PATH         = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

    ENV_EXAMPLE  = "deploy/docker/.env.example"
    ENV_FILE     = "deploy/docker/.env"

    // Upstream image only (no custom build)
    UPSTREAM_IMAGE = "postgres:16-alpine"

    // Still keep namespace/name for consistency in logs
    DOCKERHUB_USER = "thiolengkiat413"
    IMAGE_NAME     = "database"
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Determine Pipeline Mode') {
      steps {
        script {
          env.TARGET_ENV  = "build"
          env.RELEASE_TAG = (env.TAG_NAME?.trim()) ?: ""
          def branch      = env.BRANCH_NAME ?: ""
          def tagName     = env.RELEASE_TAG

          if (tagName) {
            env.TARGET_ENV = "prod"
          } else if (branch == "main") {
            env.TARGET_ENV = "staging"
          } else if (branch == "develop") {
            env.TARGET_ENV = "dev"
          } else if (branch.startsWith("release/")) {
            env.TARGET_ENV = "rc"
          } else {
            env.TARGET_ENV = "build"
          }

          echo "BRANCH_NAME: ${branch}"
          echo "TAG_NAME: ${tagName ?: 'none'}"
          echo "TARGET_ENV: ${env.TARGET_ENV}"
        }
      }
    }

    stage('Prepare .env') {
      steps {
        sh '''
          set -eux
          test -f "${ENV_EXAMPLE}"
          [ -f "${ENV_FILE}" ] || cp "${ENV_EXAMPLE}" "${ENV_FILE}"
        '''
      }
    }

    stage('Resolve Release Marker') {
      steps {
        script {
          // For DB we’re not tagging/pushing an image, but we keep a consistent “release marker”
          if (env.TARGET_ENV == "prod") {
            if (!env.RELEASE_TAG?.trim()) {
              error("Prod pipeline requires a Git tag.")
            }
            env.RELEASE_MARKER = env.RELEASE_TAG
          } else {
            env.RELEASE_MARKER = "${env.TARGET_ENV}-${env.BUILD_NUMBER}"
          }

          echo "Resolved release marker:"
          echo "  TARGET_ENV      = ${env.TARGET_ENV}"
          echo "  RELEASE_MARKER  = ${env.RELEASE_MARKER}"
          echo "  UPSTREAM_IMAGE  = ${env.UPSTREAM_IMAGE}"
        }
      }
    }

    stage('Database Setup') {
      steps {
        sh '''
          set -eux

          echo "Reset DB (fresh init.sql run)"
          docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down -v || true

          echo "Bring DB up (upstream image only)"
          docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d db
        '''
      }
    }

    stage('Smoke Test (Schema + Seed)') {
      steps {
        sh '''
          set -eux
          chmod +x tests/db-smoke.sh
          ./tests/db-smoke.sh
        '''
      }
    }

    stage('Security Scan (Docker Scout - notify only, mandatory)') {
      when { expression { return fileExists('scripts/security-docker-scout-scan.sh') } }
      steps {
        sh '''
          set -eux
          chmod +x scripts/security-docker-scout-scan.sh
          IMAGE="${UPSTREAM_IMAGE}" ./scripts/security-docker-scout-scan.sh
        '''
      }
    }

    stage('Prod Eligibility Check (tag must be on HEAD)') {
      when { expression { return env.TARGET_ENV == "prod" } }
      steps {
        sh '''
          set -eux

          echo "HEAD:"
          git show -s --oneline --decorate HEAD

          echo "Tags pointing at HEAD:"
          git tag --points-at HEAD

          if git tag --points-at HEAD | grep -qx "${TAG_NAME}"; then
            echo "OK: HEAD is correctly tagged with ${TAG_NAME}"
          else
            echo "BLOCK: HEAD is not tagged with ${TAG_NAME}"
            exit 1
          fi
        '''
      }
    }

    stage('Deploy (Dev)') {
      when { expression { return env.TARGET_ENV == "dev" } }
      steps {
        sh '''
          set -eux
          echo "Deploy placeholder (dev) — Kubernetes phase."
          echo "DB base image: ${UPSTREAM_IMAGE}"
          echo "Release marker: ${RELEASE_MARKER}"
        '''
      }
    }

    stage('Deploy (Staging)') {
      when { expression { return env.TARGET_ENV == "staging" } }
      steps {
        sh '''
          set -eux
          echo "Deploy placeholder (staging) — Kubernetes phase."
          echo "DB base image: ${UPSTREAM_IMAGE}"
          echo "Release marker: ${RELEASE_MARKER}"
        '''
      }
    }

    stage('Deploy (Prod)') {
      when { expression { return env.TARGET_ENV == "prod" } }
      steps {
        sh '''
          set -eux
          echo "Deploy placeholder (prod) — Kubernetes phase."
          echo "DB base image: ${UPSTREAM_IMAGE}"
          echo "Release tag: ${RELEASE_TAG}"
        '''
      }
    }
  }

  post {
    always {
      sh '''
        set +e
        docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" down -v || true
        rm -f "${ENV_FILE}" || true
      '''
    }
  }
}