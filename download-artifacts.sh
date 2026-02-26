#!/bin/bash

# A script to download the latest CI artifacts from all three repositories and run them locally.
# Requirements: GitHub CLI (gh) installed and authenticated.

set -e

echo "Starting artifact download for all three projects..."

# Function to get the repository name from a directory
get_repo_name() {
  local dir=$1
  if [ -d "$dir/.git" ]; then
    (cd "$dir" && gh repo view --json nameWithOwner -q .nameWithOwner)
  fi
}

# Identify the repositories
BACKEND_REPO=$(get_repo_name "./shopizer")
ADMIN_REPO=$(get_repo_name "./shopizer-admin")
SHOP_REPO=$(get_repo_name "./shopizer-shop-reactjs")

echo "--- Detected Repositories ---"
echo "Backend: $BACKEND_REPO"
echo "Admin:   $ADMIN_REPO"
echo "Shop:    $SHOP_REPO"
echo "-----------------------------"

# Create a temporary artifacts directory
mkdir -p ./ci-artifacts
cd ./ci-artifacts

# 1. Download Backend
if [ ! -z "$BACKEND_REPO" ]; then
  echo "--- Downloading Backend Artifact from $BACKEND_REPO ---"
  gh run download --name shopizer-backend --repo "$BACKEND_REPO" || echo "No backend artifact found."
fi

# 2. Download Admin
if [ ! -z "$ADMIN_REPO" ]; then
  echo "--- Downloading Admin Artifact from $ADMIN_REPO ---"
  gh run download --name shopizer-admin --repo "$ADMIN_REPO" || echo "No admin artifact found."
fi

# 3. Download Shop
if [ ! -z "$SHOP_REPO" ]; then
  echo "--- Downloading Shop React Artifact from $SHOP_REPO ---"
  gh run download --name shop-react --repo "$SHOP_REPO" || echo "No shop-react artifact found."
fi

echo "--- Artifacts downloaded successfully in ./ci-artifacts ---"

# Display instructions for running
echo ""
echo "To run the Backend:"
echo "  java -jar ./shopizer.jar"
echo ""
echo "To run the Admin Frontend (using serve or http-server):"
echo "  cd shopizer-admin && npx serve -s ."
echo ""
echo "To run the Shop React Frontend (using serve or http-server):"
echo "  cd shop-react && npx serve -s ."

cd ..
