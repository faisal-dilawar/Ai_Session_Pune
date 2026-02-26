#!/usr/bin/env bash
# =============================================================================
# stop-all.sh — Master Stop Script
# Stops all three Shopizer services: Backend, Admin UI, React Storefront
# Pass --keep-db to leave MySQL running after stopping the backend.
# =============================================================================

set -eo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$ROOT_DIR/shopizer"
ADMIN_DIR="$ROOT_DIR/shopizer-admin"
REACT_DIR="$ROOT_DIR/shopizer-shop-reactjs"

KEEP_DB_FLAG=""
[[ "${1:-}" == "--keep-db" ]] && KEEP_DB_FLAG="--keep-db"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# ── Validate module scripts exist ─────────────────────────────────────────────

for f in \
  "$BACKEND_DIR/stop.sh" \
  "$ADMIN_DIR/stop.sh" \
  "$REACT_DIR/stop.sh"; do
  if [[ ! -f "$f" ]]; then
    echo "✗ Missing script: $f"
    exit 1
  fi
  chmod +x "$f"
done

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  Shopizer — Stop All Services                    ║"
echo "╚══════════════════════════════════════════════════╝"

# ── Stop React Storefront ─────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════════════════"
echo "  [1/3] React Storefront"
echo "════════════════════════════════════════════════════"
bash "$REACT_DIR/stop.sh" || log "⚠ React stop script encountered an error"

# ── Stop Admin UI ─────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════════════════"
echo "  [2/3] Admin UI (Angular)"
echo "════════════════════════════════════════════════════"
bash "$ADMIN_DIR/stop.sh" || log "⚠ Admin stop script encountered an error"

# ── Stop Backend ──────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════════════════"
echo "  [3/3] Backend (Spring Boot)"
echo "════════════════════════════════════════════════════"
# shellcheck disable=SC2086
bash "$BACKEND_DIR/stop.sh" $KEEP_DB_FLAG || log "⚠ Backend stop script encountered an error"

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  All services stopped                            ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
if [[ -n "$KEEP_DB_FLAG" ]]; then
  echo "  MySQL is still running (--keep-db was set)"
  echo "  Stop MySQL manually: brew services stop mysql"
fi
echo ""
echo "  Restart all: ./start-all.sh"
