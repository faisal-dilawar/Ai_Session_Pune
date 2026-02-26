#!/usr/bin/env bash
# =============================================================================
# start-all.sh — Master Start Script
# Starts all three Shopizer services: Backend, Admin UI, React Storefront
# =============================================================================

set -eo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$ROOT_DIR/shopizer"
ADMIN_DIR="$ROOT_DIR/shopizer-admin"
REACT_DIR="$ROOT_DIR/shopizer-shop-reactjs"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# ── Validate module scripts exist ─────────────────────────────────────────────

for f in \
  "$BACKEND_DIR/start.sh" \
  "$ADMIN_DIR/start.sh" \
  "$REACT_DIR/start.sh"; do
  if [[ ! -f "$f" ]]; then
    echo "✗ Missing script: $f"
    exit 1
  fi
  chmod +x "$f"
done

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  Shopizer — Start All Services                   ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "Starting services in order:"
echo "  1. Admin UI (Angular)     → http://localhost:4200  (first: needs most RAM to compile)"
echo "  2. Backend  (Spring Boot) → http://localhost:8080"
echo "  3. Storefront (React)     → http://localhost:3000"
echo ""
echo "  Note: Admin UI is started first so Angular compilation gets full"
echo "        memory. Backend/React startup does not depend on each other."
echo ""

# ── 1. Admin UI ───────────────────────────────────────────────────────────────
# Start Admin first — Angular compilation needs the most RAM (~2-4 GB) and
# takes the longest. Starting it before other services prevents OOM kills.

echo "════════════════════════════════════════════════════"
echo "  [1/3] Admin UI (Angular)"
echo "════════════════════════════════════════════════════"

bash "$ADMIN_DIR/start.sh" || {
  echo ""
  echo "⚠ Admin UI failed to start. Continuing with other services."
  echo "  Fix it, then run: ./shopizer-admin/start.sh"
}

# Give Angular compilation a head start before launching memory-hungry backend
log "Admin UI compiling in background. Waiting 20s before starting Backend..."
sleep 20

# ── 2. Backend ────────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════════════════"
echo "  [2/3] Backend (Spring Boot)"
echo "════════════════════════════════════════════════════"

bash "$BACKEND_DIR/start.sh" || {
  echo ""
  echo "✗ Backend failed to start."
  echo "  Fix the backend first, then run: ./shopizer/start.sh"
}

# ── 3. React Storefront ───────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════════════════"
echo "  [3/3] React Storefront"
echo "════════════════════════════════════════════════════"

bash "$REACT_DIR/start.sh" || {
  echo ""
  echo "⚠ React storefront failed to start. Other services are still running."
  echo "  Fix it, then run: ./shopizer-shop-reactjs/start.sh"
}

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  All services started                            ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "  Service      │ URL                     │ Log"
echo "  ─────────────┼─────────────────────────┼──────────────────────────────"
echo "  Backend      │ http://localhost:8080   │ shopizer/logs/backend.log"
echo "  Admin UI     │ http://localhost:4200   │ shopizer-admin/logs/admin.log"
echo "  Storefront   │ http://localhost:3000   │ shopizer-shop-reactjs/logs/reactjs.log"
echo ""
echo "  Swagger UI   │ http://localhost:8080/swagger-ui.html"
echo ""
echo "  Note: Admin UI takes 60-90s to compile. Backend takes 30-60s to start."
echo ""
echo "  Stop all:    ./stop-all.sh"
echo "  View logs:   tail -f shopizer/logs/backend.log"
