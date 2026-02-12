pipeline {
  agent any

  environment {
    COMPOSE_FILE = "deploy/docker/docker-compose.yml"
    ENV_FILE     = "deploy/docker/.env"
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Code Compilation and Linter Checks') {
      steps {
        echo "Database service only has schema sql files and no code compilation and meaningful linters can be ran."
        echo "Skipping to Build and Validate Stage"
      }
    }

    stage('Build / Validate') {
      steps {
        sh '''
          set -eux
          test -f "${COMPOSE_FILE}"
          test -f "schema/init.sql"
          test -f "tests/db-smoke.sh"
        '''
      }
    }

    stage('Test (Schema + Integration)') {
      steps {
        sh '''
          set -eux
          ./tests/db-smoke.sh
        '''
      }
    }

    stage('Security Scan (Docker Scout - notify only)') {
      when { expression { return fileExists('scripts/security-docker-scout-scan.sh') } }
      steps {
        sh '''
          set -eux
          ./scripts/security-docker-scout-scan.sh
        '''
      }
    }

    stage('Container Build / Push / Deploy') {
      steps {
        echo "Database uses official postgres image; no build/push/deploy in this repo."
      }
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