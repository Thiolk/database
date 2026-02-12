#!/usr/bin/env bash
set -euo pipefail

# Image you deploy in compose (pin this if you want reproducibility)
IMAGE="${IMAGE:-postgres:16-alpine}"

# Fail build if HIGH/CRITICAL exist (adjust if your rubric wants MEDIUM too)
SEVERITIES="${SEVERITIES:-critical,high}"

echo "Docker Scout CVE scan"
echo "Image:      ${IMAGE}"
echo "Severities: ${SEVERITIES}"
echo

# Optional: quick summary
docker scout quickview "${IMAGE}" || true
echo

# CVE scan with CI gate
docker scout cves "${IMAGE}" --only-severity "${SEVERITIES}" --exit-code
echo
echo "PASS: No ${SEVERITIES} vulnerabilities detected in ${IMAGE}"