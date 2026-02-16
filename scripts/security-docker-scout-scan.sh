#!/usr/bin/env bash
set -euo pipefail

# Image you deploy in compose (pin this if you want reproducibility)
IMAGE="${IMAGE:-postgres:16-alpine}"

# Severity filter for reporting (does NOT fail pipeline)
SEVERITIES="${SEVERITIES:-critical,high}"

echo "Docker Scout CVE scan (notify-only; does not fail CI)"
echo "Image:      ${IMAGE}"
echo "Severities: ${SEVERITIES}"
echo

docker scout quickview "${IMAGE}" || true
echo

docker scout cves "${IMAGE}" --only-severity "${SEVERITIES}" || true
echo
echo "NOTE: CVEs (if any) are reported for visibility but do not fail the pipeline."