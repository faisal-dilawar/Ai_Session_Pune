#!/bin/bash

# Master Script for Infrastructure Provisioning and Deployment
# Requires: Colima, Ansible, and GitHub CLI installed.

set -e

echo "--- 1. Checking Virtual Machine (Colima) ---"
if ! colima status >/dev/null 2>&1; then
    echo "Colima is not running. Starting VM..."
    colima start --cpu 2 --memory 4 --disk 20
else
    echo "Colima is already running."
fi

echo ""
echo "--- 2. Synchronizing Artifacts from GitHub CI ---"
./download-artifacts.sh

# Verify artifacts exist before proceeding
if [ ! -f "./ci-artifacts/shopizer.jar" ]; then
    echo "Error: Backend artifact not found. Ensure CI build has finished on GitHub."
    exit 1
fi

echo ""
echo "--- 3. Provisioning and Deploying via Ansible ---"

# Dynamic Port Detection: Update inventory.ini with the current Colima SSH port
CURRENT_PORT=$(colima ssh-config | grep Port | awk '{print $2}')
echo "Detected Colima SSH Port: $CURRENT_PORT"
sed -i '' "s/ansible_port=[0-9]*/ansible_port=$CURRENT_PORT/" ansible/inventory.ini

# Run Ansible
ansible-playbook -i ansible/inventory.ini ansible/site.yml

echo ""
echo "---------------------------------------------------"
echo "DEPLOYMENT COMPLETE!"
echo "---------------------------------------------------"
echo "Your Shopizer system is now running inside the VM."
echo "Access points:"
echo "- Admin Panel: http://localhost/admin"
echo "- Shop Front:  http://localhost/shop"
echo "- Backend API: http://localhost/api"
echo "---------------------------------------------------"
