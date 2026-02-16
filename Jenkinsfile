pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  environment {
    COMPOSE_FILE = "deploy/docker/docker-compose.yml"
    PATH = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    DOCKERHUB_USER   = "thiolengkiat413"
    ENV_FILE     = "deploy/docker/.env"
    UPSTREAM_IMAGE = "postgres:16-alpine"
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Determine Pipeline Mode') {
      steps {
        script {
          // Jenkins multibranch common envs:
          // - CHANGE_ID exists for PRs
          // - BRANCH_NAME is the branch
          // - TAG_NAME exists when building a tag (in many setups)
          env.IMAGE_TAG   = ""
          env.TARGET_ENV  = "build"

          def branch  = env.BRANCH_NAME ?: ""
          def tagName = env.TAG_NAME?.trim()
          env.RELEASE_TAG = tagName ?: ""

          if (tagName) {
            env.TARGET_ENV = "prod"        // manual trigger via pushing a git tag
          } else if (branch == "develop") {
            env.TARGET_ENV = "dev"
          } else if (branch.startsWith("release/")) {
            env.TARGET_ENV = "staging"
          }

          echo "BRANCH_NAME: ${branch}"
          echo "TAG_NAME: ${tagName ?: 'none'}"
          echo "TARGET_ENV: ${env.TARGET_ENV}"
        }
      }
    }

    stage('Database Setup') {
      steps {
        sh '''
          set -eux
          cp deploy/docker/.env.example deploy/docker/.env
          
          # Reset DB
          echo "Reset DB (fresh init.sql run)"
          docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down -v || true

          # Bring DB up
          docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" up -d db
        '''
      }
    }

    stage('Smoke Test (Schema + Seed)') {
      steps {
        sh '''
          set -eux
          # Run your existing smoke script (keep it as source-of-truth)

          chmod +x tests/db-smoke.sh
          ./tests/db-smoke.sh
        '''
      }
    }

    stage('Security Scan (Docker Scout - notify only)') {
      when { expression { return fileExists('scripts/security-docker-scout-scan.sh') } }
      steps {
        sh '''
          set -eux
          chmod +x scripts/security-docker-scout-scan.sh
          IMAGE="${UPSTREAM_IMAGE}" ./scripts/security-docker-scout-scan.sh
        '''
      }
    }

    stage('Resolve Image Tags') {
      steps {
        script {
          def tag = env.TAG_NAME ?: ""
          if (env.PIPELINE_MODE == "prod" && tag) {
            env.IMAGE_TAG = tag
          } else {
            env.IMAGE_TAG = "build-${env.BUILD_NUMBER}"
          }
          echo "Resolved IMAGE_TAG=${env.IMAGE_TAG}"
        }
      }
    }

    stage('Deploy (dev)') {
      when { expression { return env.PIPELINE_MODE == "dev" } }
      steps { echo "Deploy placeholder (dev) — will be implemented in Kubernetes phase." }
    }

    stage('Deploy (staging)') {
      when { expression { return env.PIPELINE_MODE == "staging" } }
      steps { echo "Deploy placeholder (staging) — will be implemented in Kubernetes phase." }
    }

    stage('Deploy (prod)') {
      when { expression { return env.PIPELINE_MODE == "prod" } }
      steps { echo "Deploy placeholder (prod) — will be implemented in Kubernetes phase." }
    }
  }

  post {
    always {
      sh '''
        set +e
        docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" down -v
      '''
    }
  }
}