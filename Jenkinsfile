pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  parameters {
    choice(
      name: 'FORCE_ENV',
      choices: ['auto', 'build', 'rc', 'dev', 'staging', 'prod'],
      description: 'Override pipeline mode for testing. auto = use branch/tag logic.'
    )
    string(
      name: 'FORCE_IMAGE_TAG',
      defaultValue: '',
      description: 'Optional. If set, use this exact image tag instead of resolving from env/build number/tag.'
    )
  }

  environment {
    PATH = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

    // Upstream-only (no custom build)
    UPSTREAM_IMAGE = "postgres:16-alpine"

    // Kustomize overlays
    K8S_DIR = "k8s/database/overlays"

    // Smoke test job manifest (runs inside cluster)
    DB_SMOKE_JOB = "k8s/database/base/smoke-job.yaml"

    // Keep these for consistent logging
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

          def forced = (params.FORCE_ENV ?: 'auto').trim()
          if (forced && forced != 'auto') {
            env.TARGET_ENV = forced
            echo "FORCE_ENV override applied -> TARGET_ENV=${env.TARGET_ENV}"
          }

          echo "BRANCH_NAME: ${branch}"
          echo "TAG_NAME: ${tagName ?: 'none'}"
          echo "TARGET_ENV: ${env.TARGET_ENV}"
        }
      }
    }

    stage('Resolve Release Marker') {
      steps {
        script {
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

    stage('Validate Kustomize (compile check)') {
      steps {
        sh '''
          set -eux

          if [ "${TARGET_ENV}" = "dev" ] || [ "${TARGET_ENV}" = "staging" ] || [ "${TARGET_ENV}" = "prod" ]; then
            OVERLAY="${K8S_DIR}/${TARGET_ENV}"
          else
            # For build/rc, validate dev overlay (or change to staging if you prefer stricter)
            OVERLAY="${K8S_DIR}/dev"
          fi

          echo "Validating overlay: ${OVERLAY}"
          kubectl kustomize "${OVERLAY}" >/tmp/db-rendered.yaml
          test -s /tmp/db-rendered.yaml
          echo "Rendered manifests size:"
          wc -l /tmp/db-rendered.yaml
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

    stage('Prod Approval') {
      when { expression { return env.TARGET_ENV == "prod" } }
      steps {
        script {
          timeout(time: 30, unit: 'MINUTES') {
            input message: "Approve PROD deploy for database? (Tag: ${env.RELEASE_TAG})", ok: "Deploy"
          }
        }
      }
    }

    stage('Deploy + Smoke Test (Dev/Staging/Prod)') {
      when { expression { return env.TARGET_ENV in ["dev","staging","prod"] } }
      steps {
        withCredentials([file(credentialsId: 'kubeconfig-minikube', variable: 'KUBECONFIG_FILE')]) {
          sh '''
            set -eux
            export KUBECONFIG="$KUBECONFIG_FILE"

            NS="${TARGET_ENV}"
            OVERLAY="${K8S_DIR}/${TARGET_ENV}"

            echo "Applying DB manifests"
            kubectl kustomize "$OVERLAY" | kubectl -n "$NS" apply -f -

            echo "Wait for PVC to be bound (best-effort)"
            kubectl -n "$NS" wait --for=jsonpath='{.status.phase}'=Bound pvc/postgres-data --timeout=120s || true

            echo "Wait for deployment rollout"
            kubectl -n "$NS" rollout status deployment/postgres --timeout=180s

            echo "Run DB smoke test job"
            kubectl -n "$NS" apply -f "$DB_SMOKE_JOB"
            kubectl -n "$NS" wait --for=condition=complete job/postgres-smoke --timeout=240s
            kubectl -n "$NS" logs job/postgres-smoke

            echo "Cleanup smoke job"
            kubectl -n "$NS" delete job/postgres-smoke --ignore-not-found

            RAW_MARKER="jenkins-${JOB_NAME}-${BUILD_NUMBER}"
            # replace anything not [A-Za-z0-9_.-] with '-'
            MARKER="$(echo "$RAW_MARKER" | sed 's/[^A-Za-z0-9_.-]/-/g')"
            echo "PVC marker: $MARKER"

            # --- 1) Write marker ---
            sed "s|__MARKER__|${MARKER}|g" k8s/database/base/pvc-write-job.yaml | kubectl -n "$NS" apply --validate=false -f -
            kubectl -n "$NS" wait --for=condition=complete job/postgres-pvc-write --timeout=240s
            kubectl -n "$NS" logs job/postgres-pvc-write
            kubectl -n "$NS" delete job/postgres-pvc-write --ignore-not-found

            # --- 2) Restart postgres (forces detach/reattach of PVC) ---
            kubectl -n "$NS" rollout restart deployment/postgres
            kubectl -n "$NS" rollout status deployment/postgres --timeout=180s

            # --- 3) Read marker ---
            sed "s|__MARKER__|${MARKER}|g" k8s/database/base/pvc-read-job.yaml  | kubectl -n "$NS" apply --validate=false -f -
            kubectl -n "$NS" wait --for=condition=complete job/postgres-pvc-read --timeout=240s
            kubectl -n "$NS" logs job/postgres-pvc-read
            kubectl -n "$NS" delete job/postgres-pvc-read --ignore-not-found
          '''
        }
      }
    }
  }

  post {
    always {
      script {
        def didDeploy = (env.TARGET_ENV in ['dev', 'staging', 'prod'])

        sh '''
          set +e
          echo "========== POST (always) =========="
          echo "JOB:        ${JOB_NAME}"
          echo "BUILD:      ${BUILD_NUMBER}"
          echo "BRANCH:     ${BRANCH_NAME:-none}"
          echo "TAG:        ${TAG_NAME:-none}"
          echo "TARGET_ENV: ${TARGET_ENV:-unknown}"
          echo "RELEASE:    ${RELEASE_MARKER:-none}"
          echo "UPSTREAM:   ${UPSTREAM_IMAGE}"
          echo "WORKSPACE:  ${WORKSPACE}"
          echo "==================================="

          mkdir -p artifacts || true
          if [ -f /tmp/db-rendered.yaml ]; then
            cp -f /tmp/db-rendered.yaml artifacts/db-rendered.yaml || true
          fi
        '''

        if (didDeploy) {
          withCredentials([file(credentialsId: 'kubeconfig-minikube', variable: 'KUBECONFIG_FILE')]) {
            sh '''
              set +e
              export KUBECONFIG="$KUBECONFIG_FILE"

              NS="${TARGET_ENV}"

              echo ""
              echo "========== K8S DEBUG (ns=$NS) =========="

              echo "-- Snapshot --"
              kubectl -n "$NS" get deploy,rs,po,svc,pvc -o wide || true

              echo ""
              echo "-- Describe DB resources --"
              kubectl -n "$NS" describe deployment postgres || true
              kubectl -n "$NS" describe svc postgres || true
              kubectl -n "$NS" describe pvc postgres-data || true

              echo ""
              echo "-- Pod logs (last 200 lines each) --"
              for p in $(kubectl -n "$NS" get pods -l app=postgres -o name 2>/dev/null | sed 's#pod/##'); do
                echo ""
                echo "### logs: $p"
                kubectl -n "$NS" logs "$p" --tail=200 || true
              done

              echo ""
              echo "-- Recent events (last 60) --"
              kubectl -n "$NS" get events --sort-by=.lastTimestamp | tail -n 60 || true

              echo "========================================"
            '''
          }
        }
      }

      archiveArtifacts artifacts: 'artifacts/**', allowEmptyArchive: true
    }

    failure {
      sh '''
        set +e
        echo "Build FAILED. Check console logs + archived artifacts/."
      '''
    }

    cleanup {
      sh '''
        set +e
        rm -rf artifacts || true
      '''
    }
  }
}